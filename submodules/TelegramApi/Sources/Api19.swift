public extension Api {
    enum StickerSet: TypeConstructorDescription {
        case stickerSet(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumbs: [Api.PhotoSize]?, thumbDcId: Int32?, thumbVersion: Int32?, count: Int32, hash: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSet(let flags, let installedDate, let id, let accessHash, let title, let shortName, let thumbs, let thumbDcId, let thumbVersion, let count, let hash):
                    if boxed {
                        buffer.appendInt32(-673242758)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(installedDate!, buffer: buffer, boxed: false)}
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(thumbs!.count))
                    for item in thumbs! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(thumbDcId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(thumbVersion!, buffer: buffer, boxed: false)}
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSet(let flags, let installedDate, let id, let accessHash, let title, let shortName, let thumbs, let thumbDcId, let thumbVersion, let count, let hash):
                return ("stickerSet", [("flags", String(describing: flags)), ("installedDate", String(describing: installedDate)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("title", String(describing: title)), ("shortName", String(describing: shortName)), ("thumbs", String(describing: thumbs)), ("thumbDcId", String(describing: thumbDcId)), ("thumbVersion", String(describing: thumbVersion)), ("count", String(describing: count)), ("hash", String(describing: hash))])
    }
    }
    
        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: [Api.PhotoSize]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.StickerSet.stickerSet(flags: _1!, installedDate: _2, id: _3!, accessHash: _4!, title: _5!, shortName: _6!, thumbs: _7, thumbDcId: _8, thumbVersion: _9, count: _10!, hash: _11!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StickerSetCovered: TypeConstructorDescription {
        case stickerSetCovered(set: Api.StickerSet, cover: Api.Document)
        case stickerSetMultiCovered(set: Api.StickerSet, covers: [Api.Document])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSetCovered(let set, let cover):
                    if boxed {
                        buffer.appendInt32(1678812626)
                    }
                    set.serialize(buffer, true)
                    cover.serialize(buffer, true)
                    break
                case .stickerSetMultiCovered(let set, let covers):
                    if boxed {
                        buffer.appendInt32(872932635)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(covers.count))
                    for item in covers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSetCovered(let set, let cover):
                return ("stickerSetCovered", [("set", String(describing: set)), ("cover", String(describing: cover))])
                case .stickerSetMultiCovered(let set, let covers):
                return ("stickerSetMultiCovered", [("set", String(describing: set)), ("covers", String(describing: covers))])
    }
    }
    
        public static func parse_stickerSetCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerSetCovered.stickerSetCovered(set: _1!, cover: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetMultiCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerSetCovered.stickerSetMultiCovered(set: _1!, covers: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Theme: TypeConstructorDescription {
        case theme(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: [Api.ThemeSettings]?, emoticon: String?, installsCount: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .theme(let flags, let id, let accessHash, let slug, let title, let document, let settings, let emoticon, let installsCount):
                    if boxed {
                        buffer.appendInt32(-1609668650)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(settings!.count))
                    for item in settings! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(emoticon!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(installsCount!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .theme(let flags, let id, let accessHash, let slug, let title, let document, let settings, let emoticon, let installsCount):
                return ("theme", [("flags", String(describing: flags)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("slug", String(describing: slug)), ("title", String(describing: title)), ("document", String(describing: document)), ("settings", String(describing: settings)), ("emoticon", String(describing: emoticon)), ("installsCount", String(describing: installsCount))])
    }
    }
    
        public static func parse_theme(_ reader: BufferReader) -> Theme? {
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
            var _6: Api.Document?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _7: [Api.ThemeSettings]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ThemeSettings.self)
            } }
            var _8: String?
            if Int(_1!) & Int(1 << 6) != 0 {_8 = parseString(reader) }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_9 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Theme.theme(flags: _1!, id: _2!, accessHash: _3!, slug: _4!, title: _5!, document: _6, settings: _7, emoticon: _8, installsCount: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ThemeSettings: TypeConstructorDescription {
        case themeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.WallPaper?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .themeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper):
                    if boxed {
                        buffer.appendInt32(-94849324)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    baseTheme.serialize(buffer, true)
                    serializeInt32(accentColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(outboxAccentColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messageColors!.count))
                    for item in messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaper!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .themeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper):
                return ("themeSettings", [("flags", String(describing: flags)), ("baseTheme", String(describing: baseTheme)), ("accentColor", String(describing: accentColor)), ("outboxAccentColor", String(describing: outboxAccentColor)), ("messageColors", String(describing: messageColors)), ("wallpaper", String(describing: wallpaper))])
    }
    }
    
        public static func parse_themeSettings(_ reader: BufferReader) -> ThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            var _6: Api.WallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WallPaper
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ThemeSettings.themeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TopPeer: TypeConstructorDescription {
        case topPeer(peer: Api.Peer, rating: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeer(let peer, let rating):
                    if boxed {
                        buffer.appendInt32(-305282981)
                    }
                    peer.serialize(buffer, true)
                    serializeDouble(rating, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeer(let peer, let rating):
                return ("topPeer", [("peer", String(describing: peer)), ("rating", String(describing: rating))])
    }
    }
    
        public static func parse_topPeer(_ reader: BufferReader) -> TopPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TopPeer.topPeer(peer: _1!, rating: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TopPeerCategory: TypeConstructorDescription {
        case topPeerCategoryBotsInline
        case topPeerCategoryBotsPM
        case topPeerCategoryChannels
        case topPeerCategoryCorrespondents
        case topPeerCategoryForwardChats
        case topPeerCategoryForwardUsers
        case topPeerCategoryGroups
        case topPeerCategoryPhoneCalls
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeerCategoryBotsInline:
                    if boxed {
                        buffer.appendInt32(344356834)
                    }
                    
                    break
                case .topPeerCategoryBotsPM:
                    if boxed {
                        buffer.appendInt32(-1419371685)
                    }
                    
                    break
                case .topPeerCategoryChannels:
                    if boxed {
                        buffer.appendInt32(371037736)
                    }
                    
                    break
                case .topPeerCategoryCorrespondents:
                    if boxed {
                        buffer.appendInt32(104314861)
                    }
                    
                    break
                case .topPeerCategoryForwardChats:
                    if boxed {
                        buffer.appendInt32(-68239120)
                    }
                    
                    break
                case .topPeerCategoryForwardUsers:
                    if boxed {
                        buffer.appendInt32(-1472172887)
                    }
                    
                    break
                case .topPeerCategoryGroups:
                    if boxed {
                        buffer.appendInt32(-1122524854)
                    }
                    
                    break
                case .topPeerCategoryPhoneCalls:
                    if boxed {
                        buffer.appendInt32(511092620)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeerCategoryBotsInline:
                return ("topPeerCategoryBotsInline", [])
                case .topPeerCategoryBotsPM:
                return ("topPeerCategoryBotsPM", [])
                case .topPeerCategoryChannels:
                return ("topPeerCategoryChannels", [])
                case .topPeerCategoryCorrespondents:
                return ("topPeerCategoryCorrespondents", [])
                case .topPeerCategoryForwardChats:
                return ("topPeerCategoryForwardChats", [])
                case .topPeerCategoryForwardUsers:
                return ("topPeerCategoryForwardUsers", [])
                case .topPeerCategoryGroups:
                return ("topPeerCategoryGroups", [])
                case .topPeerCategoryPhoneCalls:
                return ("topPeerCategoryPhoneCalls", [])
    }
    }
    
        public static func parse_topPeerCategoryBotsInline(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsInline
        }
        public static func parse_topPeerCategoryBotsPM(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsPM
        }
        public static func parse_topPeerCategoryChannels(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryChannels
        }
        public static func parse_topPeerCategoryCorrespondents(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryCorrespondents
        }
        public static func parse_topPeerCategoryForwardChats(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardChats
        }
        public static func parse_topPeerCategoryForwardUsers(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardUsers
        }
        public static func parse_topPeerCategoryGroups(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryGroups
        }
        public static func parse_topPeerCategoryPhoneCalls(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryPhoneCalls
        }
    
    }
}
public extension Api {
    enum TopPeerCategoryPeers: TypeConstructorDescription {
        case topPeerCategoryPeers(category: Api.TopPeerCategory, count: Int32, peers: [Api.TopPeer])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeerCategoryPeers(let category, let count, let peers):
                    if boxed {
                        buffer.appendInt32(-75283823)
                    }
                    category.serialize(buffer, true)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeerCategoryPeers(let category, let count, let peers):
                return ("topPeerCategoryPeers", [("category", String(describing: category)), ("count", String(describing: count)), ("peers", String(describing: peers))])
    }
    }
    
        public static func parse_topPeerCategoryPeers(_ reader: BufferReader) -> TopPeerCategoryPeers? {
            var _1: Api.TopPeerCategory?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TopPeerCategory
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.TopPeer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TopPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.TopPeerCategoryPeers.topPeerCategoryPeers(category: _1!, count: _2!, peers: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Update: TypeConstructorDescription {
        case updateAttachMenuBots
        case updateBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, peer: Api.Peer, msgId: Int32, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateBotChatInviteRequester(peer: Api.Peer, date: Int32, userId: Int64, about: String, invite: Api.ExportedChatInvite, qts: Int32)
        case updateBotCommands(peer: Api.Peer, botId: Int64, commands: [Api.BotCommand])
        case updateBotInlineQuery(flags: Int32, queryId: Int64, userId: Int64, query: String, geo: Api.GeoPoint?, peerType: Api.InlineQueryPeerType?, offset: String)
        case updateBotInlineSend(flags: Int32, userId: Int64, query: String, geo: Api.GeoPoint?, id: String, msgId: Api.InputBotInlineMessageID?)
        case updateBotMenuButton(botId: Int64, button: Api.BotMenuButton)
        case updateBotPrecheckoutQuery(flags: Int32, queryId: Int64, userId: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, currency: String, totalAmount: Int64)
        case updateBotShippingQuery(queryId: Int64, userId: Int64, payload: Buffer, shippingAddress: Api.PostAddress)
        case updateBotStopped(userId: Int64, date: Int32, stopped: Api.Bool, qts: Int32)
        case updateBotWebhookJSON(data: Api.DataJSON)
        case updateBotWebhookJSONQuery(queryId: Int64, data: Api.DataJSON, timeout: Int32)
        case updateChannel(channelId: Int64)
        case updateChannelAvailableMessages(channelId: Int64, availableMinId: Int32)
        case updateChannelMessageForwards(channelId: Int64, id: Int32, forwards: Int32)
        case updateChannelMessageViews(channelId: Int64, id: Int32, views: Int32)
        case updateChannelParticipant(flags: Int32, channelId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChannelParticipant?, newParticipant: Api.ChannelParticipant?, invite: Api.ExportedChatInvite?, qts: Int32)
        case updateChannelReadMessagesContents(channelId: Int64, messages: [Int32])
        case updateChannelTooLong(flags: Int32, channelId: Int64, pts: Int32?)
        case updateChannelUserTyping(flags: Int32, channelId: Int64, topMsgId: Int32?, fromId: Api.Peer, action: Api.SendMessageAction)
        case updateChannelWebPage(channelId: Int64, webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateChat(chatId: Int64)
        case updateChatDefaultBannedRights(peer: Api.Peer, defaultBannedRights: Api.ChatBannedRights, version: Int32)
        case updateChatParticipant(flags: Int32, chatId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChatParticipant?, newParticipant: Api.ChatParticipant?, invite: Api.ExportedChatInvite?, qts: Int32)
        case updateChatParticipantAdd(chatId: Int64, userId: Int64, inviterId: Int64, date: Int32, version: Int32)
        case updateChatParticipantAdmin(chatId: Int64, userId: Int64, isAdmin: Api.Bool, version: Int32)
        case updateChatParticipantDelete(chatId: Int64, userId: Int64, version: Int32)
        case updateChatParticipants(participants: Api.ChatParticipants)
        case updateChatUserTyping(chatId: Int64, fromId: Api.Peer, action: Api.SendMessageAction)
        case updateConfig
        case updateContactsReset
        case updateDcOptions(dcOptions: [Api.DcOption])
        case updateDeleteChannelMessages(channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateDeleteMessages(messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateDeleteScheduledMessages(peer: Api.Peer, messages: [Int32])
        case updateDialogFilter(flags: Int32, id: Int32, filter: Api.DialogFilter?)
        case updateDialogFilterOrder(order: [Int32])
        case updateDialogFilters
        case updateDialogPinned(flags: Int32, folderId: Int32?, peer: Api.DialogPeer)
        case updateDialogUnreadMark(flags: Int32, peer: Api.DialogPeer)
        case updateDraftMessage(peer: Api.Peer, draft: Api.DraftMessage)
        case updateEditChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateEditMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateEncryptedChatTyping(chatId: Int32)
        case updateEncryptedMessagesRead(chatId: Int32, maxDate: Int32, date: Int32)
        case updateEncryption(chat: Api.EncryptedChat, date: Int32)
        case updateFavedStickers
        case updateFolderPeers(folderPeers: [Api.FolderPeer], pts: Int32, ptsCount: Int32)
        case updateGeoLiveViewed(peer: Api.Peer, msgId: Int32)
        case updateGroupCall(chatId: Int64, call: Api.GroupCall)
        case updateGroupCallConnection(flags: Int32, params: Api.DataJSON)
        case updateGroupCallParticipants(call: Api.InputGroupCall, participants: [Api.GroupCallParticipant], version: Int32)
        case updateInlineBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, msgId: Api.InputBotInlineMessageID, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateLangPack(difference: Api.LangPackDifference)
        case updateLangPackTooLong(langCode: String)
        case updateLoginToken
        case updateMessageID(id: Int32, randomId: Int64)
        case updateMessagePoll(flags: Int32, pollId: Int64, poll: Api.Poll?, results: Api.PollResults)
        case updateMessagePollVote(pollId: Int64, userId: Int64, options: [Buffer], qts: Int32)
        case updateMessageReactions(peer: Api.Peer, msgId: Int32, reactions: Api.MessageReactions)
        case updateNewChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateNewEncryptedMessage(message: Api.EncryptedMessage, qts: Int32)
        case updateNewMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateNewScheduledMessage(message: Api.Message)
        case updateNewStickerSet(stickerset: Api.messages.StickerSet)
        case updateNotifySettings(peer: Api.NotifyPeer, notifySettings: Api.PeerNotifySettings)
        case updatePeerBlocked(peerId: Api.Peer, blocked: Api.Bool)
        case updatePeerHistoryTTL(flags: Int32, peer: Api.Peer, ttlPeriod: Int32?)
        case updatePeerLocated(peers: [Api.PeerLocated])
        case updatePeerSettings(peer: Api.Peer, settings: Api.PeerSettings)
        case updatePendingJoinRequests(peer: Api.Peer, requestsPending: Int32, recentRequesters: [Int64])
        case updatePhoneCall(phoneCall: Api.PhoneCall)
        case updatePhoneCallSignalingData(phoneCallId: Int64, data: Buffer)
        case updatePinnedChannelMessages(flags: Int32, channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updatePinnedDialogs(flags: Int32, folderId: Int32?, order: [Api.DialogPeer]?)
        case updatePinnedMessages(flags: Int32, peer: Api.Peer, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updatePrivacy(key: Api.PrivacyKey, rules: [Api.PrivacyRule])
        case updatePtsChanged
        case updateReadChannelDiscussionInbox(flags: Int32, channelId: Int64, topMsgId: Int32, readMaxId: Int32, broadcastId: Int64?, broadcastPost: Int32?)
        case updateReadChannelDiscussionOutbox(channelId: Int64, topMsgId: Int32, readMaxId: Int32)
        case updateReadChannelInbox(flags: Int32, folderId: Int32?, channelId: Int64, maxId: Int32, stillUnreadCount: Int32, pts: Int32)
        case updateReadChannelOutbox(channelId: Int64, maxId: Int32)
        case updateReadFeaturedStickers
        case updateReadHistoryInbox(flags: Int32, folderId: Int32?, peer: Api.Peer, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32)
        case updateReadHistoryOutbox(peer: Api.Peer, maxId: Int32, pts: Int32, ptsCount: Int32)
        case updateReadMessagesContents(messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateRecentStickers
        case updateSavedGifs
        case updateSavedRingtones
        case updateServiceNotification(flags: Int32, inboxDate: Int32?, type: String, message: String, media: Api.MessageMedia, entities: [Api.MessageEntity])
        case updateStickerSets
        case updateStickerSetsOrder(flags: Int32, order: [Int64])
        case updateTheme(theme: Api.Theme)
        case updateUserName(userId: Int64, firstName: String, lastName: String, username: String)
        case updateUserPhone(userId: Int64, phone: String)
        case updateUserPhoto(userId: Int64, date: Int32, photo: Api.UserProfilePhoto, previous: Api.Bool)
        case updateUserStatus(userId: Int64, status: Api.UserStatus)
        case updateUserTyping(userId: Int64, action: Api.SendMessageAction)
        case updateWebPage(webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateWebViewResultSent(queryId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .updateAttachMenuBots:
                    if boxed {
                        buffer.appendInt32(397910539)
                    }
                    
                    break
                case .updateBotCallbackQuery(let flags, let queryId, let userId, let peer, let msgId, let chatInstance, let data, let gameShortName):
                    if boxed {
                        buffer.appendInt32(-1177566067)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(gameShortName!, buffer: buffer, boxed: false)}
                    break
                case .updateBotChatInviteRequester(let peer, let date, let userId, let about, let invite, let qts):
                    if boxed {
                        buffer.appendInt32(299870598)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    invite.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotCommands(let peer, let botId, let commands):
                    if boxed {
                        buffer.appendInt32(1299263278)
                    }
                    peer.serialize(buffer, true)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(commands.count))
                    for item in commands {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateBotInlineQuery(let flags, let queryId, let userId, let query, let geo, let peerType, let offset):
                    if boxed {
                        buffer.appendInt32(1232025500)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {peerType!.serialize(buffer, true)}
                    serializeString(offset, buffer: buffer, boxed: false)
                    break
                case .updateBotInlineSend(let flags, let userId, let query, let geo, let id, let msgId):
                    if boxed {
                        buffer.appendInt32(317794823)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geo!.serialize(buffer, true)}
                    serializeString(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {msgId!.serialize(buffer, true)}
                    break
                case .updateBotMenuButton(let botId, let button):
                    if boxed {
                        buffer.appendInt32(347625491)
                    }
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    button.serialize(buffer, true)
                    break
                case .updateBotPrecheckoutQuery(let flags, let queryId, let userId, let payload, let info, let shippingOptionId, let currency, let totalAmount):
                    if boxed {
                        buffer.appendInt32(-1934976362)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    break
                case .updateBotShippingQuery(let queryId, let userId, let payload, let shippingAddress):
                    if boxed {
                        buffer.appendInt32(-1246823043)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    shippingAddress.serialize(buffer, true)
                    break
                case .updateBotStopped(let userId, let date, let stopped, let qts):
                    if boxed {
                        buffer.appendInt32(-997782967)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    stopped.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotWebhookJSON(let data):
                    if boxed {
                        buffer.appendInt32(-2095595325)
                    }
                    data.serialize(buffer, true)
                    break
                case .updateBotWebhookJSONQuery(let queryId, let data, let timeout):
                    if boxed {
                        buffer.appendInt32(-1684914010)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    serializeInt32(timeout, buffer: buffer, boxed: false)
                    break
                case .updateChannel(let channelId):
                    if boxed {
                        buffer.appendInt32(1666927625)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
                case .updateChannelAvailableMessages(let channelId, let availableMinId):
                    if boxed {
                        buffer.appendInt32(-1304443240)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(availableMinId, buffer: buffer, boxed: false)
                    break
                case .updateChannelMessageForwards(let channelId, let id, let forwards):
                    if boxed {
                        buffer.appendInt32(-761649164)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(forwards, buffer: buffer, boxed: false)
                    break
                case .updateChannelMessageViews(let channelId, let id, let views):
                    if boxed {
                        buffer.appendInt32(-232346616)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    break
                case .updateChannelParticipant(let flags, let channelId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                    if boxed {
                        buffer.appendInt32(-1738720581)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(actorId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {prevParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {newParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {invite!.serialize(buffer, true)}
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateChannelReadMessagesContents(let channelId, let messages):
                    if boxed {
                        buffer.appendInt32(1153291573)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateChannelTooLong(let flags, let channelId, let pts):
                    if boxed {
                        buffer.appendInt32(277713951)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(pts!, buffer: buffer, boxed: false)}
                    break
                case .updateChannelUserTyping(let flags, let channelId, let topMsgId, let fromId, let action):
                    if boxed {
                        buffer.appendInt32(-1937192669)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    fromId.serialize(buffer, true)
                    action.serialize(buffer, true)
                    break
                case .updateChannelWebPage(let channelId, let webpage, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(791390623)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    webpage.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateChat(let chatId):
                    if boxed {
                        buffer.appendInt32(-124097970)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .updateChatDefaultBannedRights(let peer, let defaultBannedRights, let version):
                    if boxed {
                        buffer.appendInt32(1421875280)
                    }
                    peer.serialize(buffer, true)
                    defaultBannedRights.serialize(buffer, true)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipant(let flags, let chatId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                    if boxed {
                        buffer.appendInt32(-796432838)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(actorId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {prevParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {newParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {invite!.serialize(buffer, true)}
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantAdd(let chatId, let userId, let inviterId, let date, let version):
                    if boxed {
                        buffer.appendInt32(1037718609)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantAdmin(let chatId, let userId, let isAdmin, let version):
                    if boxed {
                        buffer.appendInt32(-674602590)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    isAdmin.serialize(buffer, true)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantDelete(let chatId, let userId, let version):
                    if boxed {
                        buffer.appendInt32(-483443337)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipants(let participants):
                    if boxed {
                        buffer.appendInt32(125178264)
                    }
                    participants.serialize(buffer, true)
                    break
                case .updateChatUserTyping(let chatId, let fromId, let action):
                    if boxed {
                        buffer.appendInt32(-2092401936)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    fromId.serialize(buffer, true)
                    action.serialize(buffer, true)
                    break
                case .updateConfig:
                    if boxed {
                        buffer.appendInt32(-1574314746)
                    }
                    
                    break
                case .updateContactsReset:
                    if boxed {
                        buffer.appendInt32(1887741886)
                    }
                    
                    break
                case .updateDcOptions(let dcOptions):
                    if boxed {
                        buffer.appendInt32(-1906403213)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dcOptions.count))
                    for item in dcOptions {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateDeleteChannelMessages(let channelId, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1020437742)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateDeleteMessages(let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1576161051)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateDeleteScheduledMessages(let peer, let messages):
                    if boxed {
                        buffer.appendInt32(-1870238482)
                    }
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateDialogFilter(let flags, let id, let filter):
                    if boxed {
                        buffer.appendInt32(654302845)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {filter!.serialize(buffer, true)}
                    break
                case .updateDialogFilterOrder(let order):
                    if boxed {
                        buffer.appendInt32(-1512627963)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateDialogFilters:
                    if boxed {
                        buffer.appendInt32(889491791)
                    }
                    
                    break
                case .updateDialogPinned(let flags, let folderId, let peer):
                    if boxed {
                        buffer.appendInt32(1852826908)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    break
                case .updateDialogUnreadMark(let flags, let peer):
                    if boxed {
                        buffer.appendInt32(-513517117)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    break
                case .updateDraftMessage(let peer, let draft):
                    if boxed {
                        buffer.appendInt32(-299124375)
                    }
                    peer.serialize(buffer, true)
                    draft.serialize(buffer, true)
                    break
                case .updateEditChannelMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(457133559)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateEditMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-469536605)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateEncryptedChatTyping(let chatId):
                    if boxed {
                        buffer.appendInt32(386986326)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .updateEncryptedMessagesRead(let chatId, let maxDate, let date):
                    if boxed {
                        buffer.appendInt32(956179895)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateEncryption(let chat, let date):
                    if boxed {
                        buffer.appendInt32(-1264392051)
                    }
                    chat.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateFavedStickers:
                    if boxed {
                        buffer.appendInt32(-451831443)
                    }
                    
                    break
                case .updateFolderPeers(let folderPeers, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(422972864)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(folderPeers.count))
                    for item in folderPeers {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateGeoLiveViewed(let peer, let msgId):
                    if boxed {
                        buffer.appendInt32(-2027964103)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .updateGroupCall(let chatId, let call):
                    if boxed {
                        buffer.appendInt32(347227392)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    break
                case .updateGroupCallConnection(let flags, let params):
                    if boxed {
                        buffer.appendInt32(192428418)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    params.serialize(buffer, true)
                    break
                case .updateGroupCallParticipants(let call, let participants, let version):
                    if boxed {
                        buffer.appendInt32(-219423922)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateInlineBotCallbackQuery(let flags, let queryId, let userId, let msgId, let chatInstance, let data, let gameShortName):
                    if boxed {
                        buffer.appendInt32(1763610706)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    msgId.serialize(buffer, true)
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(gameShortName!, buffer: buffer, boxed: false)}
                    break
                case .updateLangPack(let difference):
                    if boxed {
                        buffer.appendInt32(1442983757)
                    }
                    difference.serialize(buffer, true)
                    break
                case .updateLangPackTooLong(let langCode):
                    if boxed {
                        buffer.appendInt32(1180041828)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    break
                case .updateLoginToken:
                    if boxed {
                        buffer.appendInt32(1448076945)
                    }
                    
                    break
                case .updateMessageID(let id, let randomId):
                    if boxed {
                        buffer.appendInt32(1318109142)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    break
                case .updateMessagePoll(let flags, let pollId, let poll, let results):
                    if boxed {
                        buffer.appendInt32(-1398708869)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(pollId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {poll!.serialize(buffer, true)}
                    results.serialize(buffer, true)
                    break
                case .updateMessagePollVote(let pollId, let userId, let options, let qts):
                    if boxed {
                        buffer.appendInt32(274961865)
                    }
                    serializeInt64(pollId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateMessageReactions(let peer, let msgId, let reactions):
                    if boxed {
                        buffer.appendInt32(357013699)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    reactions.serialize(buffer, true)
                    break
                case .updateNewChannelMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1656358105)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateNewEncryptedMessage(let message, let qts):
                    if boxed {
                        buffer.appendInt32(314359194)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateNewMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(522914557)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateNewScheduledMessage(let message):
                    if boxed {
                        buffer.appendInt32(967122427)
                    }
                    message.serialize(buffer, true)
                    break
                case .updateNewStickerSet(let stickerset):
                    if boxed {
                        buffer.appendInt32(1753886890)
                    }
                    stickerset.serialize(buffer, true)
                    break
                case .updateNotifySettings(let peer, let notifySettings):
                    if boxed {
                        buffer.appendInt32(-1094555409)
                    }
                    peer.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
                    break
                case .updatePeerBlocked(let peerId, let blocked):
                    if boxed {
                        buffer.appendInt32(610945826)
                    }
                    peerId.serialize(buffer, true)
                    blocked.serialize(buffer, true)
                    break
                case .updatePeerHistoryTTL(let flags, let peer, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(-1147422299)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .updatePeerLocated(let peers):
                    if boxed {
                        buffer.appendInt32(-1263546448)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    break
                case .updatePeerSettings(let peer, let settings):
                    if boxed {
                        buffer.appendInt32(1786671974)
                    }
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    break
                case .updatePendingJoinRequests(let peer, let requestsPending, let recentRequesters):
                    if boxed {
                        buffer.appendInt32(1885586395)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(requestsPending, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentRequesters.count))
                    for item in recentRequesters {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updatePhoneCall(let phoneCall):
                    if boxed {
                        buffer.appendInt32(-1425052898)
                    }
                    phoneCall.serialize(buffer, true)
                    break
                case .updatePhoneCallSignalingData(let phoneCallId, let data):
                    if boxed {
                        buffer.appendInt32(643940105)
                    }
                    serializeInt64(phoneCallId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    break
                case .updatePinnedChannelMessages(let flags, let channelId, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1538885128)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updatePinnedDialogs(let flags, let folderId, let order):
                    if boxed {
                        buffer.appendInt32(-99664734)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order!.count))
                    for item in order! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .updatePinnedMessages(let flags, let peer, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-309990731)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updatePrivacy(let key, let rules):
                    if boxed {
                        buffer.appendInt32(-298113238)
                    }
                    key.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
                        item.serialize(buffer, true)
                    }
                    break
                case .updatePtsChanged:
                    if boxed {
                        buffer.appendInt32(861169551)
                    }
                    
                    break
                case .updateReadChannelDiscussionInbox(let flags, let channelId, let topMsgId, let readMaxId, let broadcastId, let broadcastPost):
                    if boxed {
                        buffer.appendInt32(-693004986)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(broadcastId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(broadcastPost!, buffer: buffer, boxed: false)}
                    break
                case .updateReadChannelDiscussionOutbox(let channelId, let topMsgId, let readMaxId):
                    if boxed {
                        buffer.appendInt32(1767677564)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    break
                case .updateReadChannelInbox(let flags, let folderId, let channelId, let maxId, let stillUnreadCount, let pts):
                    if boxed {
                        buffer.appendInt32(-1842450928)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(stillUnreadCount, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
                case .updateReadChannelOutbox(let channelId, let maxId):
                    if boxed {
                        buffer.appendInt32(-1218471511)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    break
                case .updateReadFeaturedStickers:
                    if boxed {
                        buffer.appendInt32(1461528386)
                    }
                    
                    break
                case .updateReadHistoryInbox(let flags, let folderId, let peer, let maxId, let stillUnreadCount, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1667805217)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(stillUnreadCount, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateReadHistoryOutbox(let peer, let maxId, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(791617983)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateReadMessagesContents(let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1757493555)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateRecentStickers:
                    if boxed {
                        buffer.appendInt32(-1706939360)
                    }
                    
                    break
                case .updateSavedGifs:
                    if boxed {
                        buffer.appendInt32(-1821035490)
                    }
                    
                    break
                case .updateSavedRingtones:
                    if boxed {
                        buffer.appendInt32(1960361625)
                    }
                    
                    break
                case .updateServiceNotification(let flags, let inboxDate, let type, let message, let media, let entities):
                    if boxed {
                        buffer.appendInt32(-337352679)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(inboxDate!, buffer: buffer, boxed: false)}
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateStickerSets:
                    if boxed {
                        buffer.appendInt32(1135492588)
                    }
                    
                    break
                case .updateStickerSetsOrder(let flags, let order):
                    if boxed {
                        buffer.appendInt32(196268545)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateTheme(let theme):
                    if boxed {
                        buffer.appendInt32(-2112423005)
                    }
                    theme.serialize(buffer, true)
                    break
                case .updateUserName(let userId, let firstName, let lastName, let username):
                    if boxed {
                        buffer.appendInt32(-1007549728)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(username, buffer: buffer, boxed: false)
                    break
                case .updateUserPhone(let userId, let phone):
                    if boxed {
                        buffer.appendInt32(88680979)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
                case .updateUserPhoto(let userId, let date, let photo, let previous):
                    if boxed {
                        buffer.appendInt32(-232290676)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    previous.serialize(buffer, true)
                    break
                case .updateUserStatus(let userId, let status):
                    if boxed {
                        buffer.appendInt32(-440534818)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    status.serialize(buffer, true)
                    break
                case .updateUserTyping(let userId, let action):
                    if boxed {
                        buffer.appendInt32(-1071741569)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
                case .updateWebPage(let webpage, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(2139689491)
                    }
                    webpage.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateWebViewResultSent(let queryId):
                    if boxed {
                        buffer.appendInt32(361936797)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .updateAttachMenuBots:
                return ("updateAttachMenuBots", [])
                case .updateBotCallbackQuery(let flags, let queryId, let userId, let peer, let msgId, let chatInstance, let data, let gameShortName):
                return ("updateBotCallbackQuery", [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("userId", String(describing: userId)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("chatInstance", String(describing: chatInstance)), ("data", String(describing: data)), ("gameShortName", String(describing: gameShortName))])
                case .updateBotChatInviteRequester(let peer, let date, let userId, let about, let invite, let qts):
                return ("updateBotChatInviteRequester", [("peer", String(describing: peer)), ("date", String(describing: date)), ("userId", String(describing: userId)), ("about", String(describing: about)), ("invite", String(describing: invite)), ("qts", String(describing: qts))])
                case .updateBotCommands(let peer, let botId, let commands):
                return ("updateBotCommands", [("peer", String(describing: peer)), ("botId", String(describing: botId)), ("commands", String(describing: commands))])
                case .updateBotInlineQuery(let flags, let queryId, let userId, let query, let geo, let peerType, let offset):
                return ("updateBotInlineQuery", [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("userId", String(describing: userId)), ("query", String(describing: query)), ("geo", String(describing: geo)), ("peerType", String(describing: peerType)), ("offset", String(describing: offset))])
                case .updateBotInlineSend(let flags, let userId, let query, let geo, let id, let msgId):
                return ("updateBotInlineSend", [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("query", String(describing: query)), ("geo", String(describing: geo)), ("id", String(describing: id)), ("msgId", String(describing: msgId))])
                case .updateBotMenuButton(let botId, let button):
                return ("updateBotMenuButton", [("botId", String(describing: botId)), ("button", String(describing: button))])
                case .updateBotPrecheckoutQuery(let flags, let queryId, let userId, let payload, let info, let shippingOptionId, let currency, let totalAmount):
                return ("updateBotPrecheckoutQuery", [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("userId", String(describing: userId)), ("payload", String(describing: payload)), ("info", String(describing: info)), ("shippingOptionId", String(describing: shippingOptionId)), ("currency", String(describing: currency)), ("totalAmount", String(describing: totalAmount))])
                case .updateBotShippingQuery(let queryId, let userId, let payload, let shippingAddress):
                return ("updateBotShippingQuery", [("queryId", String(describing: queryId)), ("userId", String(describing: userId)), ("payload", String(describing: payload)), ("shippingAddress", String(describing: shippingAddress))])
                case .updateBotStopped(let userId, let date, let stopped, let qts):
                return ("updateBotStopped", [("userId", String(describing: userId)), ("date", String(describing: date)), ("stopped", String(describing: stopped)), ("qts", String(describing: qts))])
                case .updateBotWebhookJSON(let data):
                return ("updateBotWebhookJSON", [("data", String(describing: data))])
                case .updateBotWebhookJSONQuery(let queryId, let data, let timeout):
                return ("updateBotWebhookJSONQuery", [("queryId", String(describing: queryId)), ("data", String(describing: data)), ("timeout", String(describing: timeout))])
                case .updateChannel(let channelId):
                return ("updateChannel", [("channelId", String(describing: channelId))])
                case .updateChannelAvailableMessages(let channelId, let availableMinId):
                return ("updateChannelAvailableMessages", [("channelId", String(describing: channelId)), ("availableMinId", String(describing: availableMinId))])
                case .updateChannelMessageForwards(let channelId, let id, let forwards):
                return ("updateChannelMessageForwards", [("channelId", String(describing: channelId)), ("id", String(describing: id)), ("forwards", String(describing: forwards))])
                case .updateChannelMessageViews(let channelId, let id, let views):
                return ("updateChannelMessageViews", [("channelId", String(describing: channelId)), ("id", String(describing: id)), ("views", String(describing: views))])
                case .updateChannelParticipant(let flags, let channelId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                return ("updateChannelParticipant", [("flags", String(describing: flags)), ("channelId", String(describing: channelId)), ("date", String(describing: date)), ("actorId", String(describing: actorId)), ("userId", String(describing: userId)), ("prevParticipant", String(describing: prevParticipant)), ("newParticipant", String(describing: newParticipant)), ("invite", String(describing: invite)), ("qts", String(describing: qts))])
                case .updateChannelReadMessagesContents(let channelId, let messages):
                return ("updateChannelReadMessagesContents", [("channelId", String(describing: channelId)), ("messages", String(describing: messages))])
                case .updateChannelTooLong(let flags, let channelId, let pts):
                return ("updateChannelTooLong", [("flags", String(describing: flags)), ("channelId", String(describing: channelId)), ("pts", String(describing: pts))])
                case .updateChannelUserTyping(let flags, let channelId, let topMsgId, let fromId, let action):
                return ("updateChannelUserTyping", [("flags", String(describing: flags)), ("channelId", String(describing: channelId)), ("topMsgId", String(describing: topMsgId)), ("fromId", String(describing: fromId)), ("action", String(describing: action))])
                case .updateChannelWebPage(let channelId, let webpage, let pts, let ptsCount):
                return ("updateChannelWebPage", [("channelId", String(describing: channelId)), ("webpage", String(describing: webpage)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateChat(let chatId):
                return ("updateChat", [("chatId", String(describing: chatId))])
                case .updateChatDefaultBannedRights(let peer, let defaultBannedRights, let version):
                return ("updateChatDefaultBannedRights", [("peer", String(describing: peer)), ("defaultBannedRights", String(describing: defaultBannedRights)), ("version", String(describing: version))])
                case .updateChatParticipant(let flags, let chatId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                return ("updateChatParticipant", [("flags", String(describing: flags)), ("chatId", String(describing: chatId)), ("date", String(describing: date)), ("actorId", String(describing: actorId)), ("userId", String(describing: userId)), ("prevParticipant", String(describing: prevParticipant)), ("newParticipant", String(describing: newParticipant)), ("invite", String(describing: invite)), ("qts", String(describing: qts))])
                case .updateChatParticipantAdd(let chatId, let userId, let inviterId, let date, let version):
                return ("updateChatParticipantAdd", [("chatId", String(describing: chatId)), ("userId", String(describing: userId)), ("inviterId", String(describing: inviterId)), ("date", String(describing: date)), ("version", String(describing: version))])
                case .updateChatParticipantAdmin(let chatId, let userId, let isAdmin, let version):
                return ("updateChatParticipantAdmin", [("chatId", String(describing: chatId)), ("userId", String(describing: userId)), ("isAdmin", String(describing: isAdmin)), ("version", String(describing: version))])
                case .updateChatParticipantDelete(let chatId, let userId, let version):
                return ("updateChatParticipantDelete", [("chatId", String(describing: chatId)), ("userId", String(describing: userId)), ("version", String(describing: version))])
                case .updateChatParticipants(let participants):
                return ("updateChatParticipants", [("participants", String(describing: participants))])
                case .updateChatUserTyping(let chatId, let fromId, let action):
                return ("updateChatUserTyping", [("chatId", String(describing: chatId)), ("fromId", String(describing: fromId)), ("action", String(describing: action))])
                case .updateConfig:
                return ("updateConfig", [])
                case .updateContactsReset:
                return ("updateContactsReset", [])
                case .updateDcOptions(let dcOptions):
                return ("updateDcOptions", [("dcOptions", String(describing: dcOptions))])
                case .updateDeleteChannelMessages(let channelId, let messages, let pts, let ptsCount):
                return ("updateDeleteChannelMessages", [("channelId", String(describing: channelId)), ("messages", String(describing: messages)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateDeleteMessages(let messages, let pts, let ptsCount):
                return ("updateDeleteMessages", [("messages", String(describing: messages)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateDeleteScheduledMessages(let peer, let messages):
                return ("updateDeleteScheduledMessages", [("peer", String(describing: peer)), ("messages", String(describing: messages))])
                case .updateDialogFilter(let flags, let id, let filter):
                return ("updateDialogFilter", [("flags", String(describing: flags)), ("id", String(describing: id)), ("filter", String(describing: filter))])
                case .updateDialogFilterOrder(let order):
                return ("updateDialogFilterOrder", [("order", String(describing: order))])
                case .updateDialogFilters:
                return ("updateDialogFilters", [])
                case .updateDialogPinned(let flags, let folderId, let peer):
                return ("updateDialogPinned", [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("peer", String(describing: peer))])
                case .updateDialogUnreadMark(let flags, let peer):
                return ("updateDialogUnreadMark", [("flags", String(describing: flags)), ("peer", String(describing: peer))])
                case .updateDraftMessage(let peer, let draft):
                return ("updateDraftMessage", [("peer", String(describing: peer)), ("draft", String(describing: draft))])
                case .updateEditChannelMessage(let message, let pts, let ptsCount):
                return ("updateEditChannelMessage", [("message", String(describing: message)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateEditMessage(let message, let pts, let ptsCount):
                return ("updateEditMessage", [("message", String(describing: message)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateEncryptedChatTyping(let chatId):
                return ("updateEncryptedChatTyping", [("chatId", String(describing: chatId))])
                case .updateEncryptedMessagesRead(let chatId, let maxDate, let date):
                return ("updateEncryptedMessagesRead", [("chatId", String(describing: chatId)), ("maxDate", String(describing: maxDate)), ("date", String(describing: date))])
                case .updateEncryption(let chat, let date):
                return ("updateEncryption", [("chat", String(describing: chat)), ("date", String(describing: date))])
                case .updateFavedStickers:
                return ("updateFavedStickers", [])
                case .updateFolderPeers(let folderPeers, let pts, let ptsCount):
                return ("updateFolderPeers", [("folderPeers", String(describing: folderPeers)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateGeoLiveViewed(let peer, let msgId):
                return ("updateGeoLiveViewed", [("peer", String(describing: peer)), ("msgId", String(describing: msgId))])
                case .updateGroupCall(let chatId, let call):
                return ("updateGroupCall", [("chatId", String(describing: chatId)), ("call", String(describing: call))])
                case .updateGroupCallConnection(let flags, let params):
                return ("updateGroupCallConnection", [("flags", String(describing: flags)), ("params", String(describing: params))])
                case .updateGroupCallParticipants(let call, let participants, let version):
                return ("updateGroupCallParticipants", [("call", String(describing: call)), ("participants", String(describing: participants)), ("version", String(describing: version))])
                case .updateInlineBotCallbackQuery(let flags, let queryId, let userId, let msgId, let chatInstance, let data, let gameShortName):
                return ("updateInlineBotCallbackQuery", [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("userId", String(describing: userId)), ("msgId", String(describing: msgId)), ("chatInstance", String(describing: chatInstance)), ("data", String(describing: data)), ("gameShortName", String(describing: gameShortName))])
                case .updateLangPack(let difference):
                return ("updateLangPack", [("difference", String(describing: difference))])
                case .updateLangPackTooLong(let langCode):
                return ("updateLangPackTooLong", [("langCode", String(describing: langCode))])
                case .updateLoginToken:
                return ("updateLoginToken", [])
                case .updateMessageID(let id, let randomId):
                return ("updateMessageID", [("id", String(describing: id)), ("randomId", String(describing: randomId))])
                case .updateMessagePoll(let flags, let pollId, let poll, let results):
                return ("updateMessagePoll", [("flags", String(describing: flags)), ("pollId", String(describing: pollId)), ("poll", String(describing: poll)), ("results", String(describing: results))])
                case .updateMessagePollVote(let pollId, let userId, let options, let qts):
                return ("updateMessagePollVote", [("pollId", String(describing: pollId)), ("userId", String(describing: userId)), ("options", String(describing: options)), ("qts", String(describing: qts))])
                case .updateMessageReactions(let peer, let msgId, let reactions):
                return ("updateMessageReactions", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("reactions", String(describing: reactions))])
                case .updateNewChannelMessage(let message, let pts, let ptsCount):
                return ("updateNewChannelMessage", [("message", String(describing: message)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateNewEncryptedMessage(let message, let qts):
                return ("updateNewEncryptedMessage", [("message", String(describing: message)), ("qts", String(describing: qts))])
                case .updateNewMessage(let message, let pts, let ptsCount):
                return ("updateNewMessage", [("message", String(describing: message)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateNewScheduledMessage(let message):
                return ("updateNewScheduledMessage", [("message", String(describing: message))])
                case .updateNewStickerSet(let stickerset):
                return ("updateNewStickerSet", [("stickerset", String(describing: stickerset))])
                case .updateNotifySettings(let peer, let notifySettings):
                return ("updateNotifySettings", [("peer", String(describing: peer)), ("notifySettings", String(describing: notifySettings))])
                case .updatePeerBlocked(let peerId, let blocked):
                return ("updatePeerBlocked", [("peerId", String(describing: peerId)), ("blocked", String(describing: blocked))])
                case .updatePeerHistoryTTL(let flags, let peer, let ttlPeriod):
                return ("updatePeerHistoryTTL", [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("ttlPeriod", String(describing: ttlPeriod))])
                case .updatePeerLocated(let peers):
                return ("updatePeerLocated", [("peers", String(describing: peers))])
                case .updatePeerSettings(let peer, let settings):
                return ("updatePeerSettings", [("peer", String(describing: peer)), ("settings", String(describing: settings))])
                case .updatePendingJoinRequests(let peer, let requestsPending, let recentRequesters):
                return ("updatePendingJoinRequests", [("peer", String(describing: peer)), ("requestsPending", String(describing: requestsPending)), ("recentRequesters", String(describing: recentRequesters))])
                case .updatePhoneCall(let phoneCall):
                return ("updatePhoneCall", [("phoneCall", String(describing: phoneCall))])
                case .updatePhoneCallSignalingData(let phoneCallId, let data):
                return ("updatePhoneCallSignalingData", [("phoneCallId", String(describing: phoneCallId)), ("data", String(describing: data))])
                case .updatePinnedChannelMessages(let flags, let channelId, let messages, let pts, let ptsCount):
                return ("updatePinnedChannelMessages", [("flags", String(describing: flags)), ("channelId", String(describing: channelId)), ("messages", String(describing: messages)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updatePinnedDialogs(let flags, let folderId, let order):
                return ("updatePinnedDialogs", [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("order", String(describing: order))])
                case .updatePinnedMessages(let flags, let peer, let messages, let pts, let ptsCount):
                return ("updatePinnedMessages", [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("messages", String(describing: messages)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updatePrivacy(let key, let rules):
                return ("updatePrivacy", [("key", String(describing: key)), ("rules", String(describing: rules))])
                case .updatePtsChanged:
                return ("updatePtsChanged", [])
                case .updateReadChannelDiscussionInbox(let flags, let channelId, let topMsgId, let readMaxId, let broadcastId, let broadcastPost):
                return ("updateReadChannelDiscussionInbox", [("flags", String(describing: flags)), ("channelId", String(describing: channelId)), ("topMsgId", String(describing: topMsgId)), ("readMaxId", String(describing: readMaxId)), ("broadcastId", String(describing: broadcastId)), ("broadcastPost", String(describing: broadcastPost))])
                case .updateReadChannelDiscussionOutbox(let channelId, let topMsgId, let readMaxId):
                return ("updateReadChannelDiscussionOutbox", [("channelId", String(describing: channelId)), ("topMsgId", String(describing: topMsgId)), ("readMaxId", String(describing: readMaxId))])
                case .updateReadChannelInbox(let flags, let folderId, let channelId, let maxId, let stillUnreadCount, let pts):
                return ("updateReadChannelInbox", [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("channelId", String(describing: channelId)), ("maxId", String(describing: maxId)), ("stillUnreadCount", String(describing: stillUnreadCount)), ("pts", String(describing: pts))])
                case .updateReadChannelOutbox(let channelId, let maxId):
                return ("updateReadChannelOutbox", [("channelId", String(describing: channelId)), ("maxId", String(describing: maxId))])
                case .updateReadFeaturedStickers:
                return ("updateReadFeaturedStickers", [])
                case .updateReadHistoryInbox(let flags, let folderId, let peer, let maxId, let stillUnreadCount, let pts, let ptsCount):
                return ("updateReadHistoryInbox", [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("peer", String(describing: peer)), ("maxId", String(describing: maxId)), ("stillUnreadCount", String(describing: stillUnreadCount)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateReadHistoryOutbox(let peer, let maxId, let pts, let ptsCount):
                return ("updateReadHistoryOutbox", [("peer", String(describing: peer)), ("maxId", String(describing: maxId)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateReadMessagesContents(let messages, let pts, let ptsCount):
                return ("updateReadMessagesContents", [("messages", String(describing: messages)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateRecentStickers:
                return ("updateRecentStickers", [])
                case .updateSavedGifs:
                return ("updateSavedGifs", [])
                case .updateSavedRingtones:
                return ("updateSavedRingtones", [])
                case .updateServiceNotification(let flags, let inboxDate, let type, let message, let media, let entities):
                return ("updateServiceNotification", [("flags", String(describing: flags)), ("inboxDate", String(describing: inboxDate)), ("type", String(describing: type)), ("message", String(describing: message)), ("media", String(describing: media)), ("entities", String(describing: entities))])
                case .updateStickerSets:
                return ("updateStickerSets", [])
                case .updateStickerSetsOrder(let flags, let order):
                return ("updateStickerSetsOrder", [("flags", String(describing: flags)), ("order", String(describing: order))])
                case .updateTheme(let theme):
                return ("updateTheme", [("theme", String(describing: theme))])
                case .updateUserName(let userId, let firstName, let lastName, let username):
                return ("updateUserName", [("userId", String(describing: userId)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("username", String(describing: username))])
                case .updateUserPhone(let userId, let phone):
                return ("updateUserPhone", [("userId", String(describing: userId)), ("phone", String(describing: phone))])
                case .updateUserPhoto(let userId, let date, let photo, let previous):
                return ("updateUserPhoto", [("userId", String(describing: userId)), ("date", String(describing: date)), ("photo", String(describing: photo)), ("previous", String(describing: previous))])
                case .updateUserStatus(let userId, let status):
                return ("updateUserStatus", [("userId", String(describing: userId)), ("status", String(describing: status))])
                case .updateUserTyping(let userId, let action):
                return ("updateUserTyping", [("userId", String(describing: userId)), ("action", String(describing: action))])
                case .updateWebPage(let webpage, let pts, let ptsCount):
                return ("updateWebPage", [("webpage", String(describing: webpage)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount))])
                case .updateWebViewResultSent(let queryId):
                return ("updateWebViewResultSent", [("queryId", String(describing: queryId))])
    }
    }
    
        public static func parse_updateAttachMenuBots(_ reader: BufferReader) -> Update? {
            return Api.Update.updateAttachMenuBots
        }
        public static func parse_updateBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseBytes(reader) }
            var _8: String?
            if Int(_1!) & Int(1 << 1) != 0 {_8 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, peer: _4!, msgId: _5!, chatInstance: _6!, data: _7, gameShortName: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotChatInviteRequester(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotChatInviteRequester(peer: _1!, date: _2!, userId: _3!, about: _4!, invite: _5!, qts: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotCommands(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.BotCommand]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotCommands(peer: _1!, botId: _2!, commands: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            } }
            var _6: Api.InlineQueryPeerType?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InlineQueryPeerType
            } }
            var _7: String?
            _7 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateBotInlineQuery(flags: _1!, queryId: _2!, userId: _3!, query: _4!, geo: _5, peerType: _6, offset: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineSend(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            } }
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.InputBotInlineMessageID?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotInlineSend(flags: _1!, userId: _2!, query: _3!, geo: _4, id: _5!, msgId: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMenuButton(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.BotMenuButton?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotMenuButton
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateBotMenuButton(botId: _1!, button: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotPrecheckoutQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = parseString(reader) }
            var _7: String?
            _7 = parseString(reader)
            var _8: Int64?
            _8 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBotPrecheckoutQuery(flags: _1!, queryId: _2!, userId: _3!, payload: _4!, info: _5, shippingOptionId: _6, currency: _7!, totalAmount: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotShippingQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Api.PostAddress?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PostAddress
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotShippingQuery(queryId: _1!, userId: _2!, payload: _3!, shippingAddress: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotStopped(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotStopped(userId: _1!, date: _2!, stopped: _3!, qts: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotWebhookJSON(_ reader: BufferReader) -> Update? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateBotWebhookJSON(data: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotWebhookJSONQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotWebhookJSONQuery(queryId: _1!, data: _2!, timeout: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannel(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChannel(channelId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelAvailableMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelAvailableMessages(channelId: _1!, availableMinId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelMessageForwards(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateChannelMessageForwards(channelId: _1!, id: _2!, forwards: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelMessageViews(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateChannelMessageViews(channelId: _1!, id: _2!, views: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelParticipant(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.ChannelParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            } }
            var _7: Api.ChannelParticipant?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            } }
            var _8: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            } }
            var _9: Int32?
            _9 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Update.updateChannelParticipant(flags: _1!, channelId: _2!, date: _3!, actorId: _4!, userId: _5!, prevParticipant: _6, newParticipant: _7, invite: _8, qts: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelReadMessagesContents(channelId: _1!, messages: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelTooLong(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelTooLong(flags: _1!, channelId: _2!, pts: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateChannelUserTyping(flags: _1!, channelId: _2!, topMsgId: _3, fromId: _4!, action: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelWebPage(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.WebPage?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChannelWebPage(channelId: _1!, webpage: _2!, pts: _3!, ptsCount: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChat(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatDefaultBannedRights(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatDefaultBannedRights(peer: _1!, defaultBannedRights: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipant(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
            } }
            var _7: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
            } }
            var _8: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            } }
            var _9: Int32?
            _9 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Update.updateChatParticipant(flags: _1!, chatId: _2!, date: _3!, actorId: _4!, userId: _5!, prevParticipant: _6, newParticipant: _7, invite: _8, qts: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdd(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
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
                return Api.Update.updateChatParticipantAdd(chatId: _1!, userId: _2!, inviterId: _3!, date: _4!, version: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdmin(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChatParticipantAdmin(chatId: _1!, userId: _2!, isAdmin: _3!, version: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantDelete(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatParticipantDelete(chatId: _1!, userId: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipants(_ reader: BufferReader) -> Update? {
            var _1: Api.ChatParticipants?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatParticipants
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChatParticipants(participants: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatUserTyping(chatId: _1!, fromId: _2!, action: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateConfig(_ reader: BufferReader) -> Update? {
            return Api.Update.updateConfig
        }
        public static func parse_updateContactsReset(_ reader: BufferReader) -> Update? {
            return Api.Update.updateContactsReset
        }
        public static func parse_updateDcOptions(_ reader: BufferReader) -> Update? {
            var _1: [Api.DcOption]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DcOption.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDcOptions(dcOptions: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateDeleteChannelMessages(channelId: _1!, messages: _2!, pts: _3!, ptsCount: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteMessages(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDeleteMessages(messages: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteScheduledMessages(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateDeleteScheduledMessages(peer: _1!, messages: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilter(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.DialogFilter?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DialogFilter
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogFilter(flags: _1!, id: _2!, filter: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilterOrder(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDialogFilterOrder(order: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilters(_ reader: BufferReader) -> Update? {
            return Api.Update.updateDialogFilters
        }
        public static func parse_updateDialogPinned(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogPinned(flags: _1!, folderId: _2, peer: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogUnreadMark(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateDialogUnreadMark(flags: _1!, peer: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDraftMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.DraftMessage?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateDraftMessage(peer: _1!, draft: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEditChannelMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEditChannelMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEditMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEditMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryptedChatTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateEncryptedChatTyping(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryptedMessagesRead(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateEncryptedMessagesRead(chatId: _1!, maxDate: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryption(_ reader: BufferReader) -> Update? {
            var _1: Api.EncryptedChat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EncryptedChat
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateEncryption(chat: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateFavedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateFavedStickers
        }
        public static func parse_updateFolderPeers(_ reader: BufferReader) -> Update? {
            var _1: [Api.FolderPeer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FolderPeer.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateFolderPeers(folderPeers: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGeoLiveViewed(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGeoLiveViewed(peer: _1!, msgId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCall(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.GroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GroupCall
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGroupCall(chatId: _1!, call: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallConnection(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGroupCallConnection(flags: _1!, params: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallParticipants(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateGroupCallParticipants(call: _1!, participants: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateInlineBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.InputBotInlineMessageID?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            }
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseBytes(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateInlineBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, msgId: _4!, chatInstance: _5!, data: _6, gameShortName: _7)
            }
            else {
                return nil
            }
        }
        public static func parse_updateLangPack(_ reader: BufferReader) -> Update? {
            var _1: Api.LangPackDifference?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.LangPackDifference
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateLangPack(difference: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateLangPackTooLong(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateLangPackTooLong(langCode: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateLoginToken(_ reader: BufferReader) -> Update? {
            return Api.Update.updateLoginToken
        }
        public static func parse_updateMessageID(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateMessageID(id: _1!, randomId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessagePoll(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Poll?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Poll
            } }
            var _4: Api.PollResults?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PollResults
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateMessagePoll(flags: _1!, pollId: _2!, poll: _3, results: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessagePollVote(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Buffer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateMessagePollVote(pollId: _1!, userId: _2!, options: _3!, qts: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessageReactions(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.MessageReactions?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.MessageReactions
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateMessageReactions(peer: _1!, msgId: _2!, reactions: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewChannelMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewChannelMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewEncryptedMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.EncryptedMessage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EncryptedMessage
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateNewEncryptedMessage(message: _1!, qts: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewScheduledMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewScheduledMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewStickerSet(_ reader: BufferReader) -> Update? {
            var _1: Api.messages.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewStickerSet(stickerset: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNotifySettings(_ reader: BufferReader) -> Update? {
            var _1: Api.NotifyPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.NotifyPeer
            }
            var _2: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateNotifySettings(peer: _1!, notifySettings: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerBlocked(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePeerBlocked(peerId: _1!, blocked: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerHistoryTTL(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePeerHistoryTTL(flags: _1!, peer: _2!, ttlPeriod: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerLocated(_ reader: BufferReader) -> Update? {
            var _1: [Api.PeerLocated]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerLocated.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePeerLocated(peers: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerSettings(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePeerSettings(peer: _1!, settings: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePendingJoinRequests(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Int64]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePendingJoinRequests(peer: _1!, requestsPending: _2!, recentRequesters: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePhoneCall(_ reader: BufferReader) -> Update? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePhoneCall(phoneCall: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePhoneCallSignalingData(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePhoneCallSignalingData(phoneCallId: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
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
                return Api.Update.updatePinnedChannelMessages(flags: _1!, channelId: _2!, messages: _3!, pts: _4!, ptsCount: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedDialogs(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: [Api.DialogPeer]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogPeer.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePinnedDialogs(flags: _1!, folderId: _2, order: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
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
                return Api.Update.updatePinnedMessages(flags: _1!, peer: _2!, messages: _3!, pts: _4!, ptsCount: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePrivacy(_ reader: BufferReader) -> Update? {
            var _1: Api.PrivacyKey?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PrivacyKey
            }
            var _2: [Api.PrivacyRule]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePrivacy(key: _1!, rules: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePtsChanged(_ reader: BufferReader) -> Update? {
            return Api.Update.updatePtsChanged
        }
        public static func parse_updateReadChannelDiscussionInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt64() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateReadChannelDiscussionInbox(flags: _1!, channelId: _2!, topMsgId: _3!, readMaxId: _4!, broadcastId: _5, broadcastPost: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelDiscussionOutbox(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateReadChannelDiscussionOutbox(channelId: _1!, topMsgId: _2!, readMaxId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateReadChannelInbox(flags: _1!, folderId: _2, channelId: _3!, maxId: _4!, stillUnreadCount: _5!, pts: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateReadChannelOutbox(channelId: _1!, maxId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadFeaturedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateReadFeaturedStickers
        }
        public static func parse_updateReadHistoryInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateReadHistoryInbox(flags: _1!, folderId: _2, peer: _3!, maxId: _4!, stillUnreadCount: _5!, pts: _6!, ptsCount: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadHistoryOutbox(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
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
                return Api.Update.updateReadHistoryOutbox(peer: _1!, maxId: _2!, pts: _3!, ptsCount: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadMessagesContents(messages: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateRecentStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentStickers
        }
        public static func parse_updateSavedGifs(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedGifs
        }
        public static func parse_updateSavedRingtones(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedRingtones
        }
        public static func parse_updateServiceNotification(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _6: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateServiceNotification(flags: _1!, inboxDate: _2, type: _3!, message: _4!, media: _5!, entities: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStickerSets(_ reader: BufferReader) -> Update? {
            return Api.Update.updateStickerSets
        }
        public static func parse_updateStickerSetsOrder(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStickerSetsOrder(flags: _1!, order: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateTheme(_ reader: BufferReader) -> Update? {
            var _1: Api.Theme?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Theme
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateTheme(theme: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserName(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateUserName(userId: _1!, firstName: _2!, lastName: _3!, username: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserPhone(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserPhone(userId: _1!, phone: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserPhoto(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.UserProfilePhoto?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
            }
            var _4: Api.Bool?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateUserPhoto(userId: _1!, date: _2!, photo: _3!, previous: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserStatus(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.UserStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.UserStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserStatus(userId: _1!, status: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserTyping(userId: _1!, action: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateWebPage(_ reader: BufferReader) -> Update? {
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateWebPage(webpage: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateWebViewResultSent(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateWebViewResultSent(queryId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
