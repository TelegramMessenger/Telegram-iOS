public extension Api {
public struct messages {
    public enum StickerSet: TypeConstructorDescription {
        case stickerSet(set: Api.StickerSet, packs: [Api.StickerPack], documents: [Api.Document])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSet(let set, let packs, let documents):
                    if boxed {
                        buffer.appendInt32(-1240849242)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSet(let set, let packs, let documents):
                return ("stickerSet", [("set", set), ("packs", packs), ("documents", documents)])
    }
    }
    
        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.StickerSet.stickerSet(set: _1!, packs: _2!, documents: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ArchivedStickers: TypeConstructorDescription {
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
                return ("archivedStickers", [("count", count), ("sets", sets)])
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
    public enum InactiveChats: TypeConstructorDescription {
        case inactiveChats(dates: [Int32], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inactiveChats(let dates, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1456996667)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dates.count))
                    for item in dates {
                        serializeInt32(item, buffer: buffer, boxed: false)
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
                case .inactiveChats(let dates, let chats, let users):
                return ("inactiveChats", [("dates", dates), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_inactiveChats(_ reader: BufferReader) -> InactiveChats? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
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
                return Api.messages.InactiveChats.inactiveChats(dates: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SentEncryptedMessage: TypeConstructorDescription {
        case sentEncryptedMessage(date: Int32)
        case sentEncryptedFile(date: Int32, file: Api.EncryptedFile)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentEncryptedMessage(let date):
                    if boxed {
                        buffer.appendInt32(1443858741)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .sentEncryptedFile(let date, let file):
                    if boxed {
                        buffer.appendInt32(-1802240206)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentEncryptedMessage(let date):
                return ("sentEncryptedMessage", [("date", date)])
                case .sentEncryptedFile(let date, let file):
                return ("sentEncryptedFile", [("date", date), ("file", file)])
    }
    }
    
        public static func parse_sentEncryptedMessage(_ reader: BufferReader) -> SentEncryptedMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.SentEncryptedMessage.sentEncryptedMessage(date: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentEncryptedFile(_ reader: BufferReader) -> SentEncryptedMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.EncryptedFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.EncryptedFile
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SentEncryptedMessage.sentEncryptedFile(date: _1!, file: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum VotesList: TypeConstructorDescription {
        case votesList(flags: Int32, count: Int32, votes: [Api.MessageUserVote], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .votesList(let flags, let count, let votes, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(136574537)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(votes.count))
                    for item in votes {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .votesList(let flags, let count, let votes, let users, let nextOffset):
                return ("votesList", [("flags", flags), ("count", count), ("votes", votes), ("users", users), ("nextOffset", nextOffset)])
    }
    }
    
        public static func parse_votesList(_ reader: BufferReader) -> VotesList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessageUserVote]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageUserVote.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.VotesList.votesList(flags: _1!, count: _2!, votes: _3!, users: _4!, nextOffset: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Stickers: TypeConstructorDescription {
        case stickersNotModified
        case stickers(hash: Int32, stickers: [Api.Document])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickersNotModified:
                    if boxed {
                        buffer.appendInt32(-244016606)
                    }
                    
                    break
                case .stickers(let hash, let stickers):
                    if boxed {
                        buffer.appendInt32(-463889475)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickersNotModified:
                return ("stickersNotModified", [])
                case .stickers(let hash, let stickers):
                return ("stickers", [("hash", hash), ("stickers", stickers)])
    }
    }
    
        public static func parse_stickersNotModified(_ reader: BufferReader) -> Stickers? {
            return Api.messages.Stickers.stickersNotModified
        }
        public static func parse_stickers(_ reader: BufferReader) -> Stickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Stickers.stickers(hash: _1!, stickers: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FoundStickerSets: TypeConstructorDescription {
        case foundStickerSetsNotModified
        case foundStickerSets(hash: Int32, sets: [Api.StickerSetCovered])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundStickerSetsNotModified:
                    if boxed {
                        buffer.appendInt32(223655517)
                    }
                    
                    break
                case .foundStickerSets(let hash, let sets):
                    if boxed {
                        buffer.appendInt32(1359533640)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
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
                case .foundStickerSetsNotModified:
                return ("foundStickerSetsNotModified", [])
                case .foundStickerSets(let hash, let sets):
                return ("foundStickerSets", [("hash", hash), ("sets", sets)])
    }
    }
    
        public static func parse_foundStickerSetsNotModified(_ reader: BufferReader) -> FoundStickerSets? {
            return Api.messages.FoundStickerSets.foundStickerSetsNotModified
        }
        public static func parse_foundStickerSets(_ reader: BufferReader) -> FoundStickerSets? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.FoundStickerSets.foundStickerSets(hash: _1!, sets: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FoundGifs: TypeConstructorDescription {
        case foundGifs(nextOffset: Int32, results: [Api.FoundGif])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundGifs(let nextOffset, let results):
                    if boxed {
                        buffer.appendInt32(1158290442)
                    }
                    serializeInt32(nextOffset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(results.count))
                    for item in results {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .foundGifs(let nextOffset, let results):
                return ("foundGifs", [("nextOffset", nextOffset), ("results", results)])
    }
    }
    
        public static func parse_foundGifs(_ reader: BufferReader) -> FoundGifs? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.FoundGif]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FoundGif.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.FoundGifs.foundGifs(nextOffset: _1!, results: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BotResults: TypeConstructorDescription {
        case botResults(flags: Int32, queryId: Int64, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, results: [Api.BotInlineResult], cacheTime: Int32, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botResults(let flags, let queryId, let nextOffset, let switchPm, let results, let cacheTime, let users):
                    if boxed {
                        buffer.appendInt32(-1803769784)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {switchPm!.serialize(buffer, true)}
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
                case .botResults(let flags, let queryId, let nextOffset, let switchPm, let results, let cacheTime, let users):
                return ("botResults", [("flags", flags), ("queryId", queryId), ("nextOffset", nextOffset), ("switchPm", switchPm), ("results", results), ("cacheTime", cacheTime), ("users", users)])
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
            var _5: [Api.BotInlineResult]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInlineResult.self)
            }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.messages.BotResults.botResults(flags: _1!, queryId: _2!, nextOffset: _3, switchPm: _4, results: _5!, cacheTime: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BotCallbackAnswer: TypeConstructorDescription {
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
                return ("botCallbackAnswer", [("flags", flags), ("message", message), ("url", url), ("cacheTime", cacheTime)])
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
    public enum Chats: TypeConstructorDescription {
        case chats(chats: [Api.Chat])
        case chatsSlice(count: Int32, chats: [Api.Chat])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chats(let chats):
                    if boxed {
                        buffer.appendInt32(1694474197)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    break
                case .chatsSlice(let count, let chats):
                    if boxed {
                        buffer.appendInt32(-1663561404)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chats(let chats):
                return ("chats", [("chats", chats)])
                case .chatsSlice(let count, let chats):
                return ("chatsSlice", [("count", count), ("chats", chats)])
    }
    }
    
        public static func parse_chats(_ reader: BufferReader) -> Chats? {
            var _1: [Api.Chat]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Chats.chats(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatsSlice(_ reader: BufferReader) -> Chats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Chats.chatsSlice(count: _1!, chats: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum DhConfig: TypeConstructorDescription {
        case dhConfigNotModified(random: Buffer)
        case dhConfig(g: Int32, p: Buffer, version: Int32, random: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dhConfigNotModified(let random):
                    if boxed {
                        buffer.appendInt32(-1058912715)
                    }
                    serializeBytes(random, buffer: buffer, boxed: false)
                    break
                case .dhConfig(let g, let p, let version, let random):
                    if boxed {
                        buffer.appendInt32(740433629)
                    }
                    serializeInt32(g, buffer: buffer, boxed: false)
                    serializeBytes(p, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    serializeBytes(random, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dhConfigNotModified(let random):
                return ("dhConfigNotModified", [("random", random)])
                case .dhConfig(let g, let p, let version, let random):
                return ("dhConfig", [("g", g), ("p", p), ("version", version), ("random", random)])
    }
    }
    
        public static func parse_dhConfigNotModified(_ reader: BufferReader) -> DhConfig? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.DhConfig.dhConfigNotModified(random: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_dhConfig(_ reader: BufferReader) -> DhConfig? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.DhConfig.dhConfig(g: _1!, p: _2!, version: _3!, random: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AffectedHistory: TypeConstructorDescription {
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
                return ("affectedHistory", [("pts", pts), ("ptsCount", ptsCount), ("offset", offset)])
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
    public enum MessageEditData: TypeConstructorDescription {
        case messageEditData(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageEditData(let flags):
                    if boxed {
                        buffer.appendInt32(649453030)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageEditData(let flags):
                return ("messageEditData", [("flags", flags)])
    }
    }
    
        public static func parse_messageEditData(_ reader: BufferReader) -> MessageEditData? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.MessageEditData.messageEditData(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatFull: TypeConstructorDescription {
        case chatFull(fullChat: Api.ChatFull, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatFull(let fullChat, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-438840932)
                    }
                    fullChat.serialize(buffer, true)
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
                case .chatFull(let fullChat, let chats, let users):
                return ("chatFull", [("fullChat", fullChat), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_chatFull(_ reader: BufferReader) -> ChatFull? {
            var _1: Api.ChatFull?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatFull
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
                return Api.messages.ChatFull.chatFull(fullChat: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SearchCounter: TypeConstructorDescription {
        case searchCounter(flags: Int32, filter: Api.MessagesFilter, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .searchCounter(let flags, let filter, let count):
                    if boxed {
                        buffer.appendInt32(-398136321)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    filter.serialize(buffer, true)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .searchCounter(let flags, let filter, let count):
                return ("searchCounter", [("flags", flags), ("filter", filter), ("count", count)])
    }
    }
    
        public static func parse_searchCounter(_ reader: BufferReader) -> SearchCounter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MessagesFilter?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MessagesFilter
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.SearchCounter.searchCounter(flags: _1!, filter: _2!, count: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum StickerSetInstallResult: TypeConstructorDescription {
        case stickerSetInstallResultSuccess
        case stickerSetInstallResultArchive(sets: [Api.StickerSetCovered])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSetInstallResultSuccess:
                    if boxed {
                        buffer.appendInt32(946083368)
                    }
                    
                    break
                case .stickerSetInstallResultArchive(let sets):
                    if boxed {
                        buffer.appendInt32(904138920)
                    }
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
                case .stickerSetInstallResultSuccess:
                return ("stickerSetInstallResultSuccess", [])
                case .stickerSetInstallResultArchive(let sets):
                return ("stickerSetInstallResultArchive", [("sets", sets)])
    }
    }
    
        public static func parse_stickerSetInstallResultSuccess(_ reader: BufferReader) -> StickerSetInstallResult? {
            return Api.messages.StickerSetInstallResult.stickerSetInstallResultSuccess
        }
        public static func parse_stickerSetInstallResultArchive(_ reader: BufferReader) -> StickerSetInstallResult? {
            var _1: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.StickerSetInstallResult.stickerSetInstallResultArchive(sets: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AffectedMessages: TypeConstructorDescription {
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
                return ("affectedMessages", [("pts", pts), ("ptsCount", ptsCount)])
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
    public enum SavedGifs: TypeConstructorDescription {
        case savedGifsNotModified
        case savedGifs(hash: Int32, gifs: [Api.Document])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedGifsNotModified:
                    if boxed {
                        buffer.appendInt32(-402498398)
                    }
                    
                    break
                case .savedGifs(let hash, let gifs):
                    if boxed {
                        buffer.appendInt32(772213157)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifs.count))
                    for item in gifs {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedGifsNotModified:
                return ("savedGifsNotModified", [])
                case .savedGifs(let hash, let gifs):
                return ("savedGifs", [("hash", hash), ("gifs", gifs)])
    }
    }
    
        public static func parse_savedGifsNotModified(_ reader: BufferReader) -> SavedGifs? {
            return Api.messages.SavedGifs.savedGifsNotModified
        }
        public static func parse_savedGifs(_ reader: BufferReader) -> SavedGifs? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SavedGifs.savedGifs(hash: _1!, gifs: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Messages: TypeConstructorDescription {
        case messages(messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case messagesNotModified(count: Int32)
        case channelMessages(flags: Int32, pts: Int32, count: Int32, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case messagesSlice(flags: Int32, count: Int32, nextRate: Int32?, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messages(let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1938715001)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .messagesNotModified(let count):
                    if boxed {
                        buffer.appendInt32(1951620897)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
                case .channelMessages(let flags, let pts, let count, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1725551049)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .messagesSlice(let flags, let count, let nextRate, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-923939298)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextRate!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .messages(let messages, let chats, let users):
                return ("messages", [("messages", messages), ("chats", chats), ("users", users)])
                case .messagesNotModified(let count):
                return ("messagesNotModified", [("count", count)])
                case .channelMessages(let flags, let pts, let count, let messages, let chats, let users):
                return ("channelMessages", [("flags", flags), ("pts", pts), ("count", count), ("messages", messages), ("chats", chats), ("users", users)])
                case .messagesSlice(let flags, let count, let nextRate, let messages, let chats, let users):
                return ("messagesSlice", [("flags", flags), ("count", count), ("nextRate", nextRate), ("messages", messages), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_messages(_ reader: BufferReader) -> Messages? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
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
                return Api.messages.Messages.messages(messages: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messagesNotModified(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Messages.messagesNotModified(count: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelMessages(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
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
                return Api.messages.Messages.channelMessages(flags: _1!, pts: _2!, count: _3!, messages: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_messagesSlice(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.messages.Messages.messagesSlice(flags: _1!, count: _2!, nextRate: _3, messages: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PeerDialogs: TypeConstructorDescription {
        case peerDialogs(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], state: Api.updates.State)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerDialogs(let dialogs, let messages, let chats, let users, let state):
                    if boxed {
                        buffer.appendInt32(863093588)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dialogs.count))
                    for item in dialogs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                    state.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerDialogs(let dialogs, let messages, let chats, let users, let state):
                return ("peerDialogs", [("dialogs", dialogs), ("messages", messages), ("chats", chats), ("users", users), ("state", state)])
    }
    }
    
        public static func parse_peerDialogs(_ reader: BufferReader) -> PeerDialogs? {
            var _1: [Api.Dialog]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Dialog.self)
            }
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _5: Api.updates.State?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.PeerDialogs.peerDialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!, state: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum RecentStickers: TypeConstructorDescription {
        case recentStickersNotModified
        case recentStickers(hash: Int32, packs: [Api.StickerPack], stickers: [Api.Document], dates: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentStickersNotModified:
                    if boxed {
                        buffer.appendInt32(186120336)
                    }
                    
                    break
                case .recentStickers(let hash, let packs, let stickers, let dates):
                    if boxed {
                        buffer.appendInt32(586395571)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dates.count))
                    for item in dates {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .recentStickersNotModified:
                return ("recentStickersNotModified", [])
                case .recentStickers(let hash, let packs, let stickers, let dates):
                return ("recentStickers", [("hash", hash), ("packs", packs), ("stickers", stickers), ("dates", dates)])
    }
    }
    
        public static func parse_recentStickersNotModified(_ reader: BufferReader) -> RecentStickers? {
            return Api.messages.RecentStickers.recentStickersNotModified
        }
        public static func parse_recentStickers(_ reader: BufferReader) -> RecentStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            var _4: [Int32]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.RecentStickers.recentStickers(hash: _1!, packs: _2!, stickers: _3!, dates: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FeaturedStickers: TypeConstructorDescription {
        case featuredStickersNotModified
        case featuredStickers(hash: Int32, sets: [Api.StickerSetCovered], unread: [Int64])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .featuredStickersNotModified:
                    if boxed {
                        buffer.appendInt32(82699215)
                    }
                    
                    break
                case .featuredStickers(let hash, let sets, let unread):
                    if boxed {
                        buffer.appendInt32(-123893531)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(unread.count))
                    for item in unread {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .featuredStickersNotModified:
                return ("featuredStickersNotModified", [])
                case .featuredStickers(let hash, let sets, let unread):
                return ("featuredStickers", [("hash", hash), ("sets", sets), ("unread", unread)])
    }
    }
    
        public static func parse_featuredStickersNotModified(_ reader: BufferReader) -> FeaturedStickers? {
            return Api.messages.FeaturedStickers.featuredStickersNotModified
        }
        public static func parse_featuredStickers(_ reader: BufferReader) -> FeaturedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            var _3: [Int64]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.FeaturedStickers.featuredStickers(hash: _1!, sets: _2!, unread: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Dialogs: TypeConstructorDescription {
        case dialogs(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case dialogsSlice(count: Int32, dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case dialogsNotModified(count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialogs(let dialogs, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(364538944)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dialogs.count))
                    for item in dialogs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .dialogsSlice(let count, let dialogs, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1910543603)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dialogs.count))
                    for item in dialogs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .dialogsNotModified(let count):
                    if boxed {
                        buffer.appendInt32(-253500010)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dialogs(let dialogs, let messages, let chats, let users):
                return ("dialogs", [("dialogs", dialogs), ("messages", messages), ("chats", chats), ("users", users)])
                case .dialogsSlice(let count, let dialogs, let messages, let chats, let users):
                return ("dialogsSlice", [("count", count), ("dialogs", dialogs), ("messages", messages), ("chats", chats), ("users", users)])
                case .dialogsNotModified(let count):
                return ("dialogsNotModified", [("count", count)])
    }
    }
    
        public static func parse_dialogs(_ reader: BufferReader) -> Dialogs? {
            var _1: [Api.Dialog]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Dialog.self)
            }
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.Dialogs.dialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_dialogsSlice(_ reader: BufferReader) -> Dialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Dialog]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Dialog.self)
            }
            var _3: [Api.Message]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.Dialogs.dialogsSlice(count: _1!, dialogs: _2!, messages: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_dialogsNotModified(_ reader: BufferReader) -> Dialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Dialogs.dialogsNotModified(count: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FavedStickers: TypeConstructorDescription {
        case favedStickersNotModified
        case favedStickers(hash: Int32, packs: [Api.StickerPack], stickers: [Api.Document])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .favedStickersNotModified:
                    if boxed {
                        buffer.appendInt32(-1634752813)
                    }
                    
                    break
                case .favedStickers(let hash, let packs, let stickers):
                    if boxed {
                        buffer.appendInt32(-209768682)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .favedStickersNotModified:
                return ("favedStickersNotModified", [])
                case .favedStickers(let hash, let packs, let stickers):
                return ("favedStickers", [("hash", hash), ("packs", packs), ("stickers", stickers)])
    }
    }
    
        public static func parse_favedStickersNotModified(_ reader: BufferReader) -> FavedStickers? {
            return Api.messages.FavedStickers.favedStickersNotModified
        }
        public static func parse_favedStickers(_ reader: BufferReader) -> FavedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.FavedStickers.favedStickers(hash: _1!, packs: _2!, stickers: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AllStickers: TypeConstructorDescription {
        case allStickersNotModified
        case allStickers(hash: Int32, sets: [Api.StickerSet])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .allStickersNotModified:
                    if boxed {
                        buffer.appendInt32(-395967805)
                    }
                    
                    break
                case .allStickers(let hash, let sets):
                    if boxed {
                        buffer.appendInt32(-302170017)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
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
                case .allStickersNotModified:
                return ("allStickersNotModified", [])
                case .allStickers(let hash, let sets):
                return ("allStickers", [("hash", hash), ("sets", sets)])
    }
    }
    
        public static func parse_allStickersNotModified(_ reader: BufferReader) -> AllStickers? {
            return Api.messages.AllStickers.allStickersNotModified
        }
        public static func parse_allStickers(_ reader: BufferReader) -> AllStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
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
    
    }
    public enum HighScores: TypeConstructorDescription {
        case highScores(scores: [Api.HighScore], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .highScores(let scores, let users):
                    if boxed {
                        buffer.appendInt32(-1707344487)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(scores.count))
                    for item in scores {
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
                case .highScores(let scores, let users):
                return ("highScores", [("scores", scores), ("users", users)])
    }
    }
    
        public static func parse_highScores(_ reader: BufferReader) -> HighScores? {
            var _1: [Api.HighScore]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.HighScore.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.HighScores.highScores(scores: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
    public enum InputGeoPoint: TypeConstructorDescription {
        case inputGeoPointEmpty
        case inputGeoPoint(lat: Double, long: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputGeoPointEmpty:
                    if boxed {
                        buffer.appendInt32(-457104426)
                    }
                    
                    break
                case .inputGeoPoint(let lat, let long):
                    if boxed {
                        buffer.appendInt32(-206066487)
                    }
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeDouble(long, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputGeoPointEmpty:
                return ("inputGeoPointEmpty", [])
                case .inputGeoPoint(let lat, let long):
                return ("inputGeoPoint", [("lat", lat), ("long", long)])
    }
    }
    
        public static func parse_inputGeoPointEmpty(_ reader: BufferReader) -> InputGeoPoint? {
            return Api.InputGeoPoint.inputGeoPointEmpty
        }
        public static func parse_inputGeoPoint(_ reader: BufferReader) -> InputGeoPoint? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGeoPoint.inputGeoPoint(lat: _1!, long: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatFull: TypeConstructorDescription {
        case chatFull(flags: Int32, id: Int32, about: String, participants: Api.ChatParticipants, chatPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite, botInfo: [Api.BotInfo]?, pinnedMsgId: Int32?, folderId: Int32?)
        case channelFull(flags: Int32, id: Int32, about: String, participantsCount: Int32?, adminsCount: Int32?, kickedCount: Int32?, bannedCount: Int32?, onlineCount: Int32?, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, chatPhoto: Api.Photo, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite, botInfo: [Api.BotInfo], migratedFromChatId: Int32?, migratedFromMaxId: Int32?, pinnedMsgId: Int32?, stickerset: Api.StickerSet?, availableMinId: Int32?, folderId: Int32?, linkedChatId: Int32?, location: Api.ChannelLocation?, slowmodeSeconds: Int32?, slowmodeNextSendDate: Int32?, pts: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatFull(let flags, let id, let about, let participants, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let pinnedMsgId, let folderId):
                    if boxed {
                        buffer.appendInt32(461151667)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    participants.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {chatPhoto!.serialize(buffer, true)}
                    notifySettings.serialize(buffer, true)
                    exportedInvite.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(botInfo!.count))
                    for item in botInfo! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(pinnedMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    break
                case .channelFull(let flags, let id, let about, let participantsCount, let adminsCount, let kickedCount, let bannedCount, let onlineCount, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let migratedFromChatId, let migratedFromMaxId, let pinnedMsgId, let stickerset, let availableMinId, let folderId, let linkedChatId, let location, let slowmodeSeconds, let slowmodeNextSendDate, let pts):
                    if boxed {
                        buffer.appendInt32(763976820)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(participantsCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(adminsCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(kickedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(bannedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt32(onlineCount!, buffer: buffer, boxed: false)}
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    chatPhoto.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
                    exportedInvite.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(botInfo.count))
                    for item in botInfo {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(migratedFromChatId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(migratedFromMaxId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(pinnedMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {stickerset!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(availableMinId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt32(linkedChatId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {location!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt32(slowmodeSeconds!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 18) != 0 {serializeInt32(slowmodeNextSendDate!, buffer: buffer, boxed: false)}
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatFull(let flags, let id, let about, let participants, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let pinnedMsgId, let folderId):
                return ("chatFull", [("flags", flags), ("id", id), ("about", about), ("participants", participants), ("chatPhoto", chatPhoto), ("notifySettings", notifySettings), ("exportedInvite", exportedInvite), ("botInfo", botInfo), ("pinnedMsgId", pinnedMsgId), ("folderId", folderId)])
                case .channelFull(let flags, let id, let about, let participantsCount, let adminsCount, let kickedCount, let bannedCount, let onlineCount, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let migratedFromChatId, let migratedFromMaxId, let pinnedMsgId, let stickerset, let availableMinId, let folderId, let linkedChatId, let location, let slowmodeSeconds, let slowmodeNextSendDate, let pts):
                return ("channelFull", [("flags", flags), ("id", id), ("about", about), ("participantsCount", participantsCount), ("adminsCount", adminsCount), ("kickedCount", kickedCount), ("bannedCount", bannedCount), ("onlineCount", onlineCount), ("readInboxMaxId", readInboxMaxId), ("readOutboxMaxId", readOutboxMaxId), ("unreadCount", unreadCount), ("chatPhoto", chatPhoto), ("notifySettings", notifySettings), ("exportedInvite", exportedInvite), ("botInfo", botInfo), ("migratedFromChatId", migratedFromChatId), ("migratedFromMaxId", migratedFromMaxId), ("pinnedMsgId", pinnedMsgId), ("stickerset", stickerset), ("availableMinId", availableMinId), ("folderId", folderId), ("linkedChatId", linkedChatId), ("location", location), ("slowmodeSeconds", slowmodeSeconds), ("slowmodeNextSendDate", slowmodeNextSendDate), ("pts", pts)])
    }
    }
    
        public static func parse_chatFull(_ reader: BufferReader) -> ChatFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatParticipants?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatParticipants
            }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _6: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _7: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _8: [Api.BotInfo]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_10 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.ChatFull.chatFull(flags: _1!, id: _2!, about: _3!, participants: _4!, chatPhoto: _5, notifySettings: _6!, exportedInvite: _7!, botInfo: _8, pinnedMsgId: _9, folderId: _10)
            }
            else {
                return nil
            }
        }
        public static func parse_channelFull(_ reader: BufferReader) -> ChatFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = reader.readInt32() }
            var _8: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Api.Photo?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _13: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _14: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _15: [Api.BotInfo]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
            }
            var _16: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_16 = reader.readInt32() }
            var _17: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_17 = reader.readInt32() }
            var _18: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_18 = reader.readInt32() }
            var _19: Api.StickerSet?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.StickerSet
            } }
            var _20: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {_20 = reader.readInt32() }
            var _21: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_21 = reader.readInt32() }
            var _22: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_22 = reader.readInt32() }
            var _23: Api.ChannelLocation?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _23 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
            } }
            var _24: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {_24 = reader.readInt32() }
            var _25: Int32?
            if Int(_1!) & Int(1 << 18) != 0 {_25 = reader.readInt32() }
            var _26: Int32?
            _26 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 13) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 4) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 4) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 5) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 8) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 9) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 11) == 0) || _21 != nil
            let _c22 = (Int(_1!) & Int(1 << 14) == 0) || _22 != nil
            let _c23 = (Int(_1!) & Int(1 << 15) == 0) || _23 != nil
            let _c24 = (Int(_1!) & Int(1 << 17) == 0) || _24 != nil
            let _c25 = (Int(_1!) & Int(1 << 18) == 0) || _25 != nil
            let _c26 = _26 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 {
                return Api.ChatFull.channelFull(flags: _1!, id: _2!, about: _3!, participantsCount: _4, adminsCount: _5, kickedCount: _6, bannedCount: _7, onlineCount: _8, readInboxMaxId: _9!, readOutboxMaxId: _10!, unreadCount: _11!, chatPhoto: _12!, notifySettings: _13!, exportedInvite: _14!, botInfo: _15!, migratedFromChatId: _16, migratedFromMaxId: _17, pinnedMsgId: _18, stickerset: _19, availableMinId: _20, folderId: _21, linkedChatId: _22, location: _23, slowmodeSeconds: _24, slowmodeNextSendDate: _25, pts: _26!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PollResults: TypeConstructorDescription {
        case pollResults(flags: Int32, results: [Api.PollAnswerVoters]?, totalVoters: Int32?, recentVoters: [Int32]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pollResults(let flags, let results, let totalVoters, let recentVoters):
                    if boxed {
                        buffer.appendInt32(-932174686)
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
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pollResults(let flags, let results, let totalVoters, let recentVoters):
                return ("pollResults", [("flags", flags), ("results", results), ("totalVoters", totalVoters), ("recentVoters", recentVoters)])
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
            var _4: [Int32]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PollResults.pollResults(flags: _1!, results: _2, totalVoters: _3, recentVoters: _4)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatParticipant: TypeConstructorDescription {
        case chatParticipant(userId: Int32, inviterId: Int32, date: Int32)
        case chatParticipantCreator(userId: Int32)
        case chatParticipantAdmin(userId: Int32, inviterId: Int32, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatParticipant(let userId, let inviterId, let date):
                    if boxed {
                        buffer.appendInt32(-925415106)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .chatParticipantCreator(let userId):
                    if boxed {
                        buffer.appendInt32(-636267638)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .chatParticipantAdmin(let userId, let inviterId, let date):
                    if boxed {
                        buffer.appendInt32(-489233354)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatParticipant(let userId, let inviterId, let date):
                return ("chatParticipant", [("userId", userId), ("inviterId", inviterId), ("date", date)])
                case .chatParticipantCreator(let userId):
                return ("chatParticipantCreator", [("userId", userId)])
                case .chatParticipantAdmin(let userId, let inviterId, let date):
                return ("chatParticipantAdmin", [("userId", userId), ("inviterId", inviterId), ("date", date)])
    }
    }
    
        public static func parse_chatParticipant(_ reader: BufferReader) -> ChatParticipant? {
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
                return Api.ChatParticipant.chatParticipant(userId: _1!, inviterId: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantCreator(_ reader: BufferReader) -> ChatParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatParticipant.chatParticipantCreator(userId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantAdmin(_ reader: BufferReader) -> ChatParticipant? {
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
                return Api.ChatParticipant.chatParticipantAdmin(userId: _1!, inviterId: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum CdnConfig: TypeConstructorDescription {
        case cdnConfig(publicKeys: [Api.CdnPublicKey])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .cdnConfig(let publicKeys):
                    if boxed {
                        buffer.appendInt32(1462101002)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(publicKeys.count))
                    for item in publicKeys {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .cdnConfig(let publicKeys):
                return ("cdnConfig", [("publicKeys", publicKeys)])
    }
    }
    
        public static func parse_cdnConfig(_ reader: BufferReader) -> CdnConfig? {
            var _1: [Api.CdnPublicKey]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.CdnPublicKey.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.CdnConfig.cdnConfig(publicKeys: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    indirect public enum PageBlock: TypeConstructorDescription {
        case pageBlockUnsupported
        case pageBlockTitle(text: Api.RichText)
        case pageBlockSubtitle(text: Api.RichText)
        case pageBlockAuthorDate(author: Api.RichText, publishedDate: Int32)
        case pageBlockHeader(text: Api.RichText)
        case pageBlockSubheader(text: Api.RichText)
        case pageBlockParagraph(text: Api.RichText)
        case pageBlockPreformatted(text: Api.RichText, language: String)
        case pageBlockFooter(text: Api.RichText)
        case pageBlockDivider
        case pageBlockAnchor(name: String)
        case pageBlockBlockquote(text: Api.RichText, caption: Api.RichText)
        case pageBlockPullquote(text: Api.RichText, caption: Api.RichText)
        case pageBlockCover(cover: Api.PageBlock)
        case pageBlockChannel(channel: Api.Chat)
        case pageBlockKicker(text: Api.RichText)
        case pageBlockTable(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow])
        case pageBlockPhoto(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?)
        case pageBlockVideo(flags: Int32, videoId: Int64, caption: Api.PageCaption)
        case pageBlockAudio(audioId: Int64, caption: Api.PageCaption)
        case pageBlockEmbed(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption)
        case pageBlockEmbedPost(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockCollage(items: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockSlideshow(items: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockList(items: [Api.PageListItem])
        case pageBlockOrderedList(items: [Api.PageListOrderedItem])
        case pageBlockDetails(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText)
        case pageBlockRelatedArticles(title: Api.RichText, articles: [Api.PageRelatedArticle])
        case pageBlockMap(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageBlockUnsupported:
                    if boxed {
                        buffer.appendInt32(324435594)
                    }
                    
                    break
                case .pageBlockTitle(let text):
                    if boxed {
                        buffer.appendInt32(1890305021)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockSubtitle(let text):
                    if boxed {
                        buffer.appendInt32(-1879401953)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockAuthorDate(let author, let publishedDate):
                    if boxed {
                        buffer.appendInt32(-1162877472)
                    }
                    author.serialize(buffer, true)
                    serializeInt32(publishedDate, buffer: buffer, boxed: false)
                    break
                case .pageBlockHeader(let text):
                    if boxed {
                        buffer.appendInt32(-1076861716)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockSubheader(let text):
                    if boxed {
                        buffer.appendInt32(-248793375)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockParagraph(let text):
                    if boxed {
                        buffer.appendInt32(1182402406)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockPreformatted(let text, let language):
                    if boxed {
                        buffer.appendInt32(-1066346178)
                    }
                    text.serialize(buffer, true)
                    serializeString(language, buffer: buffer, boxed: false)
                    break
                case .pageBlockFooter(let text):
                    if boxed {
                        buffer.appendInt32(1216809369)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockDivider:
                    if boxed {
                        buffer.appendInt32(-618614392)
                    }
                    
                    break
                case .pageBlockAnchor(let name):
                    if boxed {
                        buffer.appendInt32(-837994576)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    break
                case .pageBlockBlockquote(let text, let caption):
                    if boxed {
                        buffer.appendInt32(641563686)
                    }
                    text.serialize(buffer, true)
                    caption.serialize(buffer, true)
                    break
                case .pageBlockPullquote(let text, let caption):
                    if boxed {
                        buffer.appendInt32(1329878739)
                    }
                    text.serialize(buffer, true)
                    caption.serialize(buffer, true)
                    break
                case .pageBlockCover(let cover):
                    if boxed {
                        buffer.appendInt32(972174080)
                    }
                    cover.serialize(buffer, true)
                    break
                case .pageBlockChannel(let channel):
                    if boxed {
                        buffer.appendInt32(-283684427)
                    }
                    channel.serialize(buffer, true)
                    break
                case .pageBlockKicker(let text):
                    if boxed {
                        buffer.appendInt32(504660880)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockTable(let flags, let title, let rows):
                    if boxed {
                        buffer.appendInt32(-1085412734)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    title.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rows.count))
                    for item in rows {
                        item.serialize(buffer, true)
                    }
                    break
                case .pageBlockPhoto(let flags, let photoId, let caption, let url, let webpageId):
                    if boxed {
                        buffer.appendInt32(391759200)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(photoId, buffer: buffer, boxed: false)
                    caption.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(webpageId!, buffer: buffer, boxed: false)}
                    break
                case .pageBlockVideo(let flags, let videoId, let caption):
                    if boxed {
                        buffer.appendInt32(2089805750)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(videoId, buffer: buffer, boxed: false)
                    caption.serialize(buffer, true)
                    break
                case .pageBlockAudio(let audioId, let caption):
                    if boxed {
                        buffer.appendInt32(-2143067670)
                    }
                    serializeInt64(audioId, buffer: buffer, boxed: false)
                    caption.serialize(buffer, true)
                    break
                case .pageBlockEmbed(let flags, let url, let html, let posterPhotoId, let w, let h, let caption):
                    if boxed {
                        buffer.appendInt32(-1468953147)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(html!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(posterPhotoId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(w!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(h!, buffer: buffer, boxed: false)}
                    caption.serialize(buffer, true)
                    break
                case .pageBlockEmbedPost(let url, let webpageId, let authorPhotoId, let author, let date, let blocks, let caption):
                    if boxed {
                        buffer.appendInt32(-229005301)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(webpageId, buffer: buffer, boxed: false)
                    serializeInt64(authorPhotoId, buffer: buffer, boxed: false)
                    serializeString(author, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocks.count))
                    for item in blocks {
                        item.serialize(buffer, true)
                    }
                    caption.serialize(buffer, true)
                    break
                case .pageBlockCollage(let items, let caption):
                    if boxed {
                        buffer.appendInt32(1705048653)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(items.count))
                    for item in items {
                        item.serialize(buffer, true)
                    }
                    caption.serialize(buffer, true)
                    break
                case .pageBlockSlideshow(let items, let caption):
                    if boxed {
                        buffer.appendInt32(52401552)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(items.count))
                    for item in items {
                        item.serialize(buffer, true)
                    }
                    caption.serialize(buffer, true)
                    break
                case .pageBlockList(let items):
                    if boxed {
                        buffer.appendInt32(-454524911)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(items.count))
                    for item in items {
                        item.serialize(buffer, true)
                    }
                    break
                case .pageBlockOrderedList(let items):
                    if boxed {
                        buffer.appendInt32(-1702174239)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(items.count))
                    for item in items {
                        item.serialize(buffer, true)
                    }
                    break
                case .pageBlockDetails(let flags, let blocks, let title):
                    if boxed {
                        buffer.appendInt32(1987480557)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocks.count))
                    for item in blocks {
                        item.serialize(buffer, true)
                    }
                    title.serialize(buffer, true)
                    break
                case .pageBlockRelatedArticles(let title, let articles):
                    if boxed {
                        buffer.appendInt32(370236054)
                    }
                    title.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(articles.count))
                    for item in articles {
                        item.serialize(buffer, true)
                    }
                    break
                case .pageBlockMap(let geo, let zoom, let w, let h, let caption):
                    if boxed {
                        buffer.appendInt32(-1538310410)
                    }
                    geo.serialize(buffer, true)
                    serializeInt32(zoom, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    caption.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageBlockUnsupported:
                return ("pageBlockUnsupported", [])
                case .pageBlockTitle(let text):
                return ("pageBlockTitle", [("text", text)])
                case .pageBlockSubtitle(let text):
                return ("pageBlockSubtitle", [("text", text)])
                case .pageBlockAuthorDate(let author, let publishedDate):
                return ("pageBlockAuthorDate", [("author", author), ("publishedDate", publishedDate)])
                case .pageBlockHeader(let text):
                return ("pageBlockHeader", [("text", text)])
                case .pageBlockSubheader(let text):
                return ("pageBlockSubheader", [("text", text)])
                case .pageBlockParagraph(let text):
                return ("pageBlockParagraph", [("text", text)])
                case .pageBlockPreformatted(let text, let language):
                return ("pageBlockPreformatted", [("text", text), ("language", language)])
                case .pageBlockFooter(let text):
                return ("pageBlockFooter", [("text", text)])
                case .pageBlockDivider:
                return ("pageBlockDivider", [])
                case .pageBlockAnchor(let name):
                return ("pageBlockAnchor", [("name", name)])
                case .pageBlockBlockquote(let text, let caption):
                return ("pageBlockBlockquote", [("text", text), ("caption", caption)])
                case .pageBlockPullquote(let text, let caption):
                return ("pageBlockPullquote", [("text", text), ("caption", caption)])
                case .pageBlockCover(let cover):
                return ("pageBlockCover", [("cover", cover)])
                case .pageBlockChannel(let channel):
                return ("pageBlockChannel", [("channel", channel)])
                case .pageBlockKicker(let text):
                return ("pageBlockKicker", [("text", text)])
                case .pageBlockTable(let flags, let title, let rows):
                return ("pageBlockTable", [("flags", flags), ("title", title), ("rows", rows)])
                case .pageBlockPhoto(let flags, let photoId, let caption, let url, let webpageId):
                return ("pageBlockPhoto", [("flags", flags), ("photoId", photoId), ("caption", caption), ("url", url), ("webpageId", webpageId)])
                case .pageBlockVideo(let flags, let videoId, let caption):
                return ("pageBlockVideo", [("flags", flags), ("videoId", videoId), ("caption", caption)])
                case .pageBlockAudio(let audioId, let caption):
                return ("pageBlockAudio", [("audioId", audioId), ("caption", caption)])
                case .pageBlockEmbed(let flags, let url, let html, let posterPhotoId, let w, let h, let caption):
                return ("pageBlockEmbed", [("flags", flags), ("url", url), ("html", html), ("posterPhotoId", posterPhotoId), ("w", w), ("h", h), ("caption", caption)])
                case .pageBlockEmbedPost(let url, let webpageId, let authorPhotoId, let author, let date, let blocks, let caption):
                return ("pageBlockEmbedPost", [("url", url), ("webpageId", webpageId), ("authorPhotoId", authorPhotoId), ("author", author), ("date", date), ("blocks", blocks), ("caption", caption)])
                case .pageBlockCollage(let items, let caption):
                return ("pageBlockCollage", [("items", items), ("caption", caption)])
                case .pageBlockSlideshow(let items, let caption):
                return ("pageBlockSlideshow", [("items", items), ("caption", caption)])
                case .pageBlockList(let items):
                return ("pageBlockList", [("items", items)])
                case .pageBlockOrderedList(let items):
                return ("pageBlockOrderedList", [("items", items)])
                case .pageBlockDetails(let flags, let blocks, let title):
                return ("pageBlockDetails", [("flags", flags), ("blocks", blocks), ("title", title)])
                case .pageBlockRelatedArticles(let title, let articles):
                return ("pageBlockRelatedArticles", [("title", title), ("articles", articles)])
                case .pageBlockMap(let geo, let zoom, let w, let h, let caption):
                return ("pageBlockMap", [("geo", geo), ("zoom", zoom), ("w", w), ("h", h), ("caption", caption)])
    }
    }
    
        public static func parse_pageBlockUnsupported(_ reader: BufferReader) -> PageBlock? {
            return Api.PageBlock.pageBlockUnsupported
        }
        public static func parse_pageBlockTitle(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockTitle(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockSubtitle(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockSubtitle(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockAuthorDate(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockAuthorDate(author: _1!, publishedDate: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeader(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeader(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockSubheader(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockSubheader(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockParagraph(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockParagraph(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockPreformatted(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockPreformatted(text: _1!, language: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockFooter(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockFooter(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockDivider(_ reader: BufferReader) -> PageBlock? {
            return Api.PageBlock.pageBlockDivider
        }
        public static func parse_pageBlockAnchor(_ reader: BufferReader) -> PageBlock? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockAnchor(name: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockBlockquote(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockBlockquote(text: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockPullquote(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockPullquote(text: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockCover(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.PageBlock?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PageBlock
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockCover(cover: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockChannel(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.Chat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Chat
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockChannel(channel: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockKicker(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockKicker(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockTable(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _3: [Api.PageTableRow]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageTableRow.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockTable(flags: _1!, title: _2!, rows: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockPhoto(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PageCaption?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PageBlock.pageBlockPhoto(flags: _1!, photoId: _2!, caption: _3!, url: _4, webpageId: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockVideo(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PageCaption?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockVideo(flags: _1!, videoId: _2!, caption: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockAudio(_ reader: BufferReader) -> PageBlock? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockAudio(audioId: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockEmbed(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = parseString(reader) }
            var _3: String?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = parseString(reader) }
            var _4: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_4 = reader.readInt64() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_6 = reader.readInt32() }
            var _7: Api.PageCaption?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 5) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PageBlock.pageBlockEmbed(flags: _1!, url: _2, html: _3, posterPhotoId: _4, w: _5, h: _6, caption: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockEmbedPost(_ reader: BufferReader) -> PageBlock? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _7: Api.PageCaption?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PageBlock.pageBlockEmbedPost(url: _1!, webpageId: _2!, authorPhotoId: _3!, author: _4!, date: _5!, blocks: _6!, caption: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockCollage(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockCollage(items: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockSlideshow(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockSlideshow(items: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockList(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageListItem]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageListItem.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockList(items: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockOrderedList(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageListOrderedItem]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageListOrderedItem.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockOrderedList(items: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockDetails(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _3: Api.RichText?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockDetails(flags: _1!, blocks: _2!, title: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockRelatedArticles(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: [Api.PageRelatedArticle]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageRelatedArticle.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockRelatedArticles(title: _1!, articles: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockMap(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.PageCaption?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PageBlock.pageBlockMap(geo: _1!, zoom: _2!, w: _3!, h: _4!, caption: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecureRequiredType: TypeConstructorDescription {
        case secureRequiredType(flags: Int32, type: Api.SecureValueType)
        case secureRequiredTypeOneOf(types: [Api.SecureRequiredType])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureRequiredType(let flags, let type):
                    if boxed {
                        buffer.appendInt32(-2103600678)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    break
                case .secureRequiredTypeOneOf(let types):
                    if boxed {
                        buffer.appendInt32(41187252)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureRequiredType(let flags, let type):
                return ("secureRequiredType", [("flags", flags), ("type", type)])
                case .secureRequiredTypeOneOf(let types):
                return ("secureRequiredTypeOneOf", [("types", types)])
    }
    }
    
        public static func parse_secureRequiredType(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureRequiredType.secureRequiredType(flags: _1!, type: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureRequiredTypeOneOf(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecureRequiredType.secureRequiredTypeOneOf(types: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum JSONValue: TypeConstructorDescription {
        case jsonNull
        case jsonBool(value: Api.Bool)
        case jsonNumber(value: Double)
        case jsonString(value: String)
        case jsonArray(value: [Api.JSONValue])
        case jsonObject(value: [Api.JSONObjectValue])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .jsonNull:
                    if boxed {
                        buffer.appendInt32(1064139624)
                    }
                    
                    break
                case .jsonBool(let value):
                    if boxed {
                        buffer.appendInt32(-952869270)
                    }
                    value.serialize(buffer, true)
                    break
                case .jsonNumber(let value):
                    if boxed {
                        buffer.appendInt32(736157604)
                    }
                    serializeDouble(value, buffer: buffer, boxed: false)
                    break
                case .jsonString(let value):
                    if boxed {
                        buffer.appendInt32(-1222740358)
                    }
                    serializeString(value, buffer: buffer, boxed: false)
                    break
                case .jsonArray(let value):
                    if boxed {
                        buffer.appendInt32(-146520221)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(value.count))
                    for item in value {
                        item.serialize(buffer, true)
                    }
                    break
                case .jsonObject(let value):
                    if boxed {
                        buffer.appendInt32(-1715350371)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(value.count))
                    for item in value {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .jsonNull:
                return ("jsonNull", [])
                case .jsonBool(let value):
                return ("jsonBool", [("value", value)])
                case .jsonNumber(let value):
                return ("jsonNumber", [("value", value)])
                case .jsonString(let value):
                return ("jsonString", [("value", value)])
                case .jsonArray(let value):
                return ("jsonArray", [("value", value)])
                case .jsonObject(let value):
                return ("jsonObject", [("value", value)])
    }
    }
    
        public static func parse_jsonNull(_ reader: BufferReader) -> JSONValue? {
            return Api.JSONValue.jsonNull
        }
        public static func parse_jsonBool(_ reader: BufferReader) -> JSONValue? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonBool(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonNumber(_ reader: BufferReader) -> JSONValue? {
            var _1: Double?
            _1 = reader.readDouble()
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonNumber(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonString(_ reader: BufferReader) -> JSONValue? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonString(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonArray(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonArray(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonObject(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONObjectValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONObjectValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonObject(value: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Photo: TypeConstructorDescription {
        case photoEmpty(id: Int64)
        case photo(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, sizes: [Api.PhotoSize], dcId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photoEmpty(let id):
                    if boxed {
                        buffer.appendInt32(590459437)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .photo(let flags, let id, let accessHash, let fileReference, let date, let sizes, let dcId):
                    if boxed {
                        buffer.appendInt32(-797637467)
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
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photoEmpty(let id):
                return ("photoEmpty", [("id", id)])
                case .photo(let flags, let id, let accessHash, let fileReference, let date, let sizes, let dcId):
                return ("photo", [("flags", flags), ("id", id), ("accessHash", accessHash), ("fileReference", fileReference), ("date", date), ("sizes", sizes), ("dcId", dcId)])
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
                return Api.Photo.photo(flags: _1!, id: _2!, accessHash: _3!, fileReference: _4!, date: _5!, sizes: _6!, dcId: _7!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Chat: TypeConstructorDescription {
        case chatEmpty(id: Int32)
        case chatForbidden(id: Int32, title: String)
        case channelForbidden(flags: Int32, id: Int32, accessHash: Int64, title: String, untilDate: Int32?)
        case chat(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto, participantsCount: Int32, date: Int32, version: Int32, migratedTo: Api.InputChannel?, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?)
        case channel(flags: Int32, id: Int32, accessHash: Int64?, title: String, username: String?, photo: Api.ChatPhoto, date: Int32, version: Int32, restrictionReason: [Api.RestrictionReason]?, adminRights: Api.ChatAdminRights?, bannedRights: Api.ChatBannedRights?, defaultBannedRights: Api.ChatBannedRights?, participantsCount: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-1683826688)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .chatForbidden(let id, let title):
                    if boxed {
                        buffer.appendInt32(120753115)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .channelForbidden(let flags, let id, let accessHash, let title, let untilDate):
                    if boxed {
                        buffer.appendInt32(681420594)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 16) != 0 {serializeInt32(untilDate!, buffer: buffer, boxed: false)}
                    break
                case .chat(let flags, let id, let title, let photo, let participantsCount, let date, let version, let migratedTo, let adminRights, let defaultBannedRights):
                    if boxed {
                        buffer.appendInt32(1004149726)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 6) != 0 {migratedTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {adminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {defaultBannedRights!.serialize(buffer, true)}
                    break
                case .channel(let flags, let id, let accessHash, let title, let username, let photo, let date, let version, let restrictionReason, let adminRights, let bannedRights, let defaultBannedRights, let participantsCount):
                    if boxed {
                        buffer.appendInt32(-753232354)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt64(accessHash!, buffer: buffer, boxed: false)}
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    photo.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 14) != 0 {adminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {bannedRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {defaultBannedRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt32(participantsCount!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatEmpty(let id):
                return ("chatEmpty", [("id", id)])
                case .chatForbidden(let id, let title):
                return ("chatForbidden", [("id", id), ("title", title)])
                case .channelForbidden(let flags, let id, let accessHash, let title, let untilDate):
                return ("channelForbidden", [("flags", flags), ("id", id), ("accessHash", accessHash), ("title", title), ("untilDate", untilDate)])
                case .chat(let flags, let id, let title, let photo, let participantsCount, let date, let version, let migratedTo, let adminRights, let defaultBannedRights):
                return ("chat", [("flags", flags), ("id", id), ("title", title), ("photo", photo), ("participantsCount", participantsCount), ("date", date), ("version", version), ("migratedTo", migratedTo), ("adminRights", adminRights), ("defaultBannedRights", defaultBannedRights)])
                case .channel(let flags, let id, let accessHash, let title, let username, let photo, let date, let version, let restrictionReason, let adminRights, let bannedRights, let defaultBannedRights, let participantsCount):
                return ("channel", [("flags", flags), ("id", id), ("accessHash", accessHash), ("title", title), ("username", username), ("photo", photo), ("date", date), ("version", version), ("restrictionReason", restrictionReason), ("adminRights", adminRights), ("bannedRights", bannedRights), ("defaultBannedRights", defaultBannedRights), ("participantsCount", participantsCount)])
    }
    }
    
        public static func parse_chatEmpty(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Chat.chatEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatForbidden(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Chat.chatForbidden(id: _1!, title: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelForbidden(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            if Int(_1!) & Int(1 << 16) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 16) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Chat.channelForbidden(flags: _1!, id: _2!, accessHash: _3!, title: _4!, untilDate: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_chat(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatPhoto?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.InputChannel?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.InputChannel
            } }
            var _9: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _10: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 14) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 18) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.Chat.chat(flags: _1!, id: _2!, title: _3!, photo: _4!, participantsCount: _5!, date: _6!, version: _7!, migratedTo: _8, adminRights: _9, defaultBannedRights: _10)
            }
            else {
                return nil
            }
        }
        public static func parse_channel(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            if Int(_1!) & Int(1 << 13) != 0 {_3 = reader.readInt64() }
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            if Int(_1!) & Int(1 << 6) != 0 {_5 = parseString(reader) }
            var _6: Api.ChatPhoto?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 9) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            var _10: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _11: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            } }
            var _12: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            } }
            var _13: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {_13 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 13) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 6) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 9) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 15) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 17) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.Chat.channel(flags: _1!, id: _2!, accessHash: _3, title: _4!, username: _5, photo: _6!, date: _7!, version: _8!, restrictionReason: _9, adminRights: _10, bannedRights: _11, defaultBannedRights: _12, participantsCount: _13)
            }
            else {
                return nil
            }
        }
    
    }
    public enum StatsURL: TypeConstructorDescription {
        case statsURL(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsURL(let url):
                    if boxed {
                        buffer.appendInt32(1202287072)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsURL(let url):
                return ("statsURL", [("url", url)])
    }
    }
    
        public static func parse_statsURL(_ reader: BufferReader) -> StatsURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsURL.statsURL(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatInvite: TypeConstructorDescription {
        case chatInviteAlready(chat: Api.Chat)
        case chatInvite(flags: Int32, title: String, photo: Api.Photo, participantsCount: Int32, participants: [Api.User]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatInviteAlready(let chat):
                    if boxed {
                        buffer.appendInt32(1516793212)
                    }
                    chat.serialize(buffer, true)
                    break
                case .chatInvite(let flags, let title, let photo, let participantsCount, let participants):
                    if boxed {
                        buffer.appendInt32(-540871282)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants!.count))
                    for item in participants! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatInviteAlready(let chat):
                return ("chatInviteAlready", [("chat", chat)])
                case .chatInvite(let flags, let title, let photo, let participantsCount, let participants):
                return ("chatInvite", [("flags", flags), ("title", title), ("photo", photo), ("participantsCount", participantsCount), ("participants", participants)])
    }
    }
    
        public static func parse_chatInviteAlready(_ reader: BufferReader) -> ChatInvite? {
            var _1: Api.Chat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Chat
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatInvite.chatInviteAlready(chat: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatInvite(_ reader: BufferReader) -> ChatInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Photo?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: [Api.User]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChatInvite.chatInvite(flags: _1!, title: _2!, photo: _3!, participantsCount: _4!, participants: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(flags: Int32, photoSizeMax: Int32, videoSizeMax: Int32, fileSizeMax: Int32, videoUploadMaxbitrate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoDownloadSettings(let flags, let photoSizeMax, let videoSizeMax, let fileSizeMax, let videoUploadMaxbitrate):
                    if boxed {
                        buffer.appendInt32(-532532493)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(photoSizeMax, buffer: buffer, boxed: false)
                    serializeInt32(videoSizeMax, buffer: buffer, boxed: false)
                    serializeInt32(fileSizeMax, buffer: buffer, boxed: false)
                    serializeInt32(videoUploadMaxbitrate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoDownloadSettings(let flags, let photoSizeMax, let videoSizeMax, let fileSizeMax, let videoUploadMaxbitrate):
                return ("autoDownloadSettings", [("flags", flags), ("photoSizeMax", photoSizeMax), ("videoSizeMax", videoSizeMax), ("fileSizeMax", fileSizeMax), ("videoUploadMaxbitrate", videoUploadMaxbitrate)])
    }
    }
    
        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
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
                return Api.AutoDownloadSettings.autoDownloadSettings(flags: _1!, photoSizeMax: _2!, videoSizeMax: _3!, fileSizeMax: _4!, videoUploadMaxbitrate: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum StickerSetCovered: TypeConstructorDescription {
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
                return ("stickerSetCovered", [("set", set), ("cover", cover)])
                case .stickerSetMultiCovered(let set, let covers):
                return ("stickerSetMultiCovered", [("set", set), ("covers", covers)])
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
    public enum RecentMeUrl: TypeConstructorDescription {
        case recentMeUrlUnknown(url: String)
        case recentMeUrlUser(url: String, userId: Int32)
        case recentMeUrlChat(url: String, chatId: Int32)
        case recentMeUrlChatInvite(url: String, chatInvite: Api.ChatInvite)
        case recentMeUrlStickerSet(url: String, set: Api.StickerSetCovered)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentMeUrlUnknown(let url):
                    if boxed {
                        buffer.appendInt32(1189204285)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlUser(let url, let userId):
                    if boxed {
                        buffer.appendInt32(-1917045962)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlChat(let url, let chatId):
                    if boxed {
                        buffer.appendInt32(-1608834311)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlChatInvite(let url, let chatInvite):
                    if boxed {
                        buffer.appendInt32(-347535331)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    chatInvite.serialize(buffer, true)
                    break
                case .recentMeUrlStickerSet(let url, let set):
                    if boxed {
                        buffer.appendInt32(-1140172836)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    set.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .recentMeUrlUnknown(let url):
                return ("recentMeUrlUnknown", [("url", url)])
                case .recentMeUrlUser(let url, let userId):
                return ("recentMeUrlUser", [("url", url), ("userId", userId)])
                case .recentMeUrlChat(let url, let chatId):
                return ("recentMeUrlChat", [("url", url), ("chatId", chatId)])
                case .recentMeUrlChatInvite(let url, let chatInvite):
                return ("recentMeUrlChatInvite", [("url", url), ("chatInvite", chatInvite)])
                case .recentMeUrlStickerSet(let url, let set):
                return ("recentMeUrlStickerSet", [("url", url), ("set", set)])
    }
    }
    
        public static func parse_recentMeUrlUnknown(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.RecentMeUrl.recentMeUrlUnknown(url: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlUser(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlUser(url: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlChat(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlChat(url: _1!, chatId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlChatInvite(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.ChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlChatInvite(url: _1!, chatInvite: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlStickerSet(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.StickerSetCovered?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StickerSetCovered
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlStickerSet(url: _1!, set: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum RestrictionReason: TypeConstructorDescription {
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
                return ("restrictionReason", [("platform", platform), ("reason", reason), ("text", text)])
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
    indirect public enum RichText: TypeConstructorDescription {
        case textEmpty
        case textPlain(text: String)
        case textBold(text: Api.RichText)
        case textItalic(text: Api.RichText)
        case textUnderline(text: Api.RichText)
        case textStrike(text: Api.RichText)
        case textFixed(text: Api.RichText)
        case textUrl(text: Api.RichText, url: String, webpageId: Int64)
        case textEmail(text: Api.RichText, email: String)
        case textConcat(texts: [Api.RichText])
        case textSubscript(text: Api.RichText)
        case textSuperscript(text: Api.RichText)
        case textMarked(text: Api.RichText)
        case textPhone(text: Api.RichText, phone: String)
        case textImage(documentId: Int64, w: Int32, h: Int32)
        case textAnchor(text: Api.RichText, name: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .textEmpty:
                    if boxed {
                        buffer.appendInt32(-599948721)
                    }
                    
                    break
                case .textPlain(let text):
                    if boxed {
                        buffer.appendInt32(1950782688)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .textBold(let text):
                    if boxed {
                        buffer.appendInt32(1730456516)
                    }
                    text.serialize(buffer, true)
                    break
                case .textItalic(let text):
                    if boxed {
                        buffer.appendInt32(-653089380)
                    }
                    text.serialize(buffer, true)
                    break
                case .textUnderline(let text):
                    if boxed {
                        buffer.appendInt32(-1054465340)
                    }
                    text.serialize(buffer, true)
                    break
                case .textStrike(let text):
                    if boxed {
                        buffer.appendInt32(-1678197867)
                    }
                    text.serialize(buffer, true)
                    break
                case .textFixed(let text):
                    if boxed {
                        buffer.appendInt32(1816074681)
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
                case .textEmail(let text, let email):
                    if boxed {
                        buffer.appendInt32(-564523562)
                    }
                    text.serialize(buffer, true)
                    serializeString(email, buffer: buffer, boxed: false)
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
                case .textImage(let documentId, let w, let h):
                    if boxed {
                        buffer.appendInt32(136105807)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .textAnchor(let text, let name):
                    if boxed {
                        buffer.appendInt32(894777186)
                    }
                    text.serialize(buffer, true)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .textEmpty:
                return ("textEmpty", [])
                case .textPlain(let text):
                return ("textPlain", [("text", text)])
                case .textBold(let text):
                return ("textBold", [("text", text)])
                case .textItalic(let text):
                return ("textItalic", [("text", text)])
                case .textUnderline(let text):
                return ("textUnderline", [("text", text)])
                case .textStrike(let text):
                return ("textStrike", [("text", text)])
                case .textFixed(let text):
                return ("textFixed", [("text", text)])
                case .textUrl(let text, let url, let webpageId):
                return ("textUrl", [("text", text), ("url", url), ("webpageId", webpageId)])
                case .textEmail(let text, let email):
                return ("textEmail", [("text", text), ("email", email)])
                case .textConcat(let texts):
                return ("textConcat", [("texts", texts)])
                case .textSubscript(let text):
                return ("textSubscript", [("text", text)])
                case .textSuperscript(let text):
                return ("textSuperscript", [("text", text)])
                case .textMarked(let text):
                return ("textMarked", [("text", text)])
                case .textPhone(let text, let phone):
                return ("textPhone", [("text", text), ("phone", phone)])
                case .textImage(let documentId, let w, let h):
                return ("textImage", [("documentId", documentId), ("w", w), ("h", h)])
                case .textAnchor(let text, let name):
                return ("textAnchor", [("text", text), ("name", name)])
    }
    }
    
        public static func parse_textEmpty(_ reader: BufferReader) -> RichText? {
            return Api.RichText.textEmpty
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
    
    }
    public enum UserFull: TypeConstructorDescription {
        case userFull(flags: Int32, user: Api.User, about: String?, settings: Api.PeerSettings, profilePhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, botInfo: Api.BotInfo?, pinnedMsgId: Int32?, commonChatsCount: Int32, folderId: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userFull(let flags, let user, let about, let settings, let profilePhoto, let notifySettings, let botInfo, let pinnedMsgId, let commonChatsCount, let folderId):
                    if boxed {
                        buffer.appendInt32(-302941166)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    user.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    settings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {profilePhoto!.serialize(buffer, true)}
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {botInfo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(pinnedMsgId!, buffer: buffer, boxed: false)}
                    serializeInt32(commonChatsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userFull(let flags, let user, let about, let settings, let profilePhoto, let notifySettings, let botInfo, let pinnedMsgId, let commonChatsCount, let folderId):
                return ("userFull", [("flags", flags), ("user", user), ("about", about), ("settings", settings), ("profilePhoto", profilePhoto), ("notifySettings", notifySettings), ("botInfo", botInfo), ("pinnedMsgId", pinnedMsgId), ("commonChatsCount", commonChatsCount), ("folderId", folderId)])
    }
    }
    
        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.User
            }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _6: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _7: Api.BotInfo?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.BotInfo
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_10 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.UserFull.userFull(flags: _1!, user: _2!, about: _3, settings: _4!, profilePhoto: _5, notifySettings: _6!, botInfo: _7, pinnedMsgId: _8, commonChatsCount: _9!, folderId: _10)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputChannel: TypeConstructorDescription {
        case inputChannelEmpty
        case inputChannel(channelId: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChannelEmpty:
                    if boxed {
                        buffer.appendInt32(-292807034)
                    }
                    
                    break
                case .inputChannel(let channelId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1343524562)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChannelEmpty:
                return ("inputChannelEmpty", [])
                case .inputChannel(let channelId, let accessHash):
                return ("inputChannel", [("channelId", channelId), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputChannelEmpty(_ reader: BufferReader) -> InputChannel? {
            return Api.InputChannel.inputChannelEmpty
        }
        public static func parse_inputChannel(_ reader: BufferReader) -> InputChannel? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputChannel.inputChannel(channelId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum DcOption: TypeConstructorDescription {
        case dcOption(flags: Int32, id: Int32, ipAddress: String, port: Int32, secret: Buffer?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dcOption(let flags, let id, let ipAddress, let port, let secret):
                    if boxed {
                        buffer.appendInt32(414687501)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(ipAddress, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 10) != 0 {serializeBytes(secret!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dcOption(let flags, let id, let ipAddress, let port, let secret):
                return ("dcOption", [("flags", flags), ("id", id), ("ipAddress", ipAddress), ("port", port), ("secret", secret)])
    }
    }
    
        public static func parse_dcOption(_ reader: BufferReader) -> DcOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            if Int(_1!) & Int(1 << 10) != 0 {_5 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 10) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DcOption.dcOption(flags: _1!, id: _2!, ipAddress: _3!, port: _4!, secret: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PollAnswerVoters: TypeConstructorDescription {
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
                return ("pollAnswerVoters", [("flags", flags), ("option", option), ("voters", voters)])
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
    public enum LangPackLanguage: TypeConstructorDescription {
        case langPackLanguage(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .langPackLanguage(let flags, let name, let nativeName, let langCode, let baseLangCode, let pluralCode, let stringsCount, let translatedCount, let translationsUrl):
                    if boxed {
                        buffer.appendInt32(-288727837)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeString(nativeName, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(baseLangCode!, buffer: buffer, boxed: false)}
                    serializeString(pluralCode, buffer: buffer, boxed: false)
                    serializeInt32(stringsCount, buffer: buffer, boxed: false)
                    serializeInt32(translatedCount, buffer: buffer, boxed: false)
                    serializeString(translationsUrl, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .langPackLanguage(let flags, let name, let nativeName, let langCode, let baseLangCode, let pluralCode, let stringsCount, let translatedCount, let translationsUrl):
                return ("langPackLanguage", [("flags", flags), ("name", name), ("nativeName", nativeName), ("langCode", langCode), ("baseLangCode", baseLangCode), ("pluralCode", pluralCode), ("stringsCount", stringsCount), ("translatedCount", translatedCount), ("translationsUrl", translationsUrl)])
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
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
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
                return Api.LangPackLanguage.langPackLanguage(flags: _1!, name: _2!, nativeName: _3!, langCode: _4!, baseLangCode: _5, pluralCode: _6!, stringsCount: _7!, translatedCount: _8!, translationsUrl: _9!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum LangPackDifference: TypeConstructorDescription {
        case langPackDifference(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .langPackDifference(let langCode, let fromVersion, let version, let strings):
                    if boxed {
                        buffer.appendInt32(-209337866)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(strings.count))
                    for item in strings {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .langPackDifference(let langCode, let fromVersion, let version, let strings):
                return ("langPackDifference", [("langCode", langCode), ("fromVersion", fromVersion), ("version", version), ("strings", strings)])
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
                return Api.LangPackDifference.langPackDifference(langCode: _1!, fromVersion: _2!, version: _3!, strings: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WallPaperSettings: TypeConstructorDescription {
        case wallPaperSettings(flags: Int32, backgroundColor: Int32?, secondBackgroundColor: Int32?, intensity: Int32?, rotation: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .wallPaperSettings(let flags, let backgroundColor, let secondBackgroundColor, let intensity, let rotation):
                    if boxed {
                        buffer.appendInt32(84438264)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(backgroundColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(secondBackgroundColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(intensity!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(rotation!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .wallPaperSettings(let flags, let backgroundColor, let secondBackgroundColor, let intensity, let rotation):
                return ("wallPaperSettings", [("flags", flags), ("backgroundColor", backgroundColor), ("secondBackgroundColor", secondBackgroundColor), ("intensity", intensity), ("rotation", rotation)])
    }
    }
    
        public static func parse_wallPaperSettings(_ reader: BufferReader) -> WallPaperSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 4) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.WallPaperSettings.wallPaperSettings(flags: _1!, backgroundColor: _2, secondBackgroundColor: _3, intensity: _4, rotation: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum EmojiURL: TypeConstructorDescription {
        case EmojiURL(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .EmojiURL(let url):
                    if boxed {
                        buffer.appendInt32(1152191385)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .EmojiURL(let url):
                return ("EmojiURL", [("url", url)])
    }
    }
    
        public static func parse_EmojiURL(_ reader: BufferReader) -> EmojiURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiURL.EmojiURL(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputCheckPasswordSRP: TypeConstructorDescription {
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(srpId: Int64, A: Buffer, M1: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputCheckPasswordEmpty:
                    if boxed {
                        buffer.appendInt32(-1736378792)
                    }
                    
                    break
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                    if boxed {
                        buffer.appendInt32(-763367294)
                    }
                    serializeInt64(srpId, buffer: buffer, boxed: false)
                    serializeBytes(A, buffer: buffer, boxed: false)
                    serializeBytes(M1, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputCheckPasswordEmpty:
                return ("inputCheckPasswordEmpty", [])
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                return ("inputCheckPasswordSRP", [("srpId", srpId), ("A", A), ("M1", M1)])
    }
    }
    
        public static func parse_inputCheckPasswordEmpty(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            return Api.InputCheckPasswordSRP.inputCheckPasswordEmpty
        }
        public static func parse_inputCheckPasswordSRP(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputCheckPasswordSRP.inputCheckPasswordSRP(srpId: _1!, A: _2!, M1: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputEncryptedFile: TypeConstructorDescription {
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32)
        case inputEncryptedFile(id: Int64, accessHash: Int64)
        case inputEncryptedFileBigUploaded(id: Int64, parts: Int32, keyFingerprint: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedFileEmpty:
                    if boxed {
                        buffer.appendInt32(406307684)
                    }
                    
                    break
                case .inputEncryptedFileUploaded(let id, let parts, let md5Checksum, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1690108678)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFile(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1511503333)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileBigUploaded(let id, let parts, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(767652808)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedFileEmpty:
                return ("inputEncryptedFileEmpty", [])
                case .inputEncryptedFileUploaded(let id, let parts, let md5Checksum, let keyFingerprint):
                return ("inputEncryptedFileUploaded", [("id", id), ("parts", parts), ("md5Checksum", md5Checksum), ("keyFingerprint", keyFingerprint)])
                case .inputEncryptedFile(let id, let accessHash):
                return ("inputEncryptedFile", [("id", id), ("accessHash", accessHash)])
                case .inputEncryptedFileBigUploaded(let id, let parts, let keyFingerprint):
                return ("inputEncryptedFileBigUploaded", [("id", id), ("parts", parts), ("keyFingerprint", keyFingerprint)])
    }
    }
    
        public static func parse_inputEncryptedFileEmpty(_ reader: BufferReader) -> InputEncryptedFile? {
            return Api.InputEncryptedFile.inputEncryptedFileEmpty
        }
        public static func parse_inputEncryptedFileUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputEncryptedFile.inputEncryptedFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, keyFingerprint: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFile(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputEncryptedFile.inputEncryptedFile(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileBigUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
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
                return Api.InputEncryptedFile.inputEncryptedFileBigUploaded(id: _1!, parts: _2!, keyFingerprint: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ExportedMessageLink: TypeConstructorDescription {
        case exportedMessageLink(link: String, html: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedMessageLink(let link, let html):
                    if boxed {
                        buffer.appendInt32(1571494644)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    serializeString(html, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedMessageLink(let link, let html):
                return ("exportedMessageLink", [("link", link), ("html", html)])
    }
    }
    
        public static func parse_exportedMessageLink(_ reader: BufferReader) -> ExportedMessageLink? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ExportedMessageLink.exportedMessageLink(link: _1!, html: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputFile: TypeConstructorDescription {
        case inputFile(id: Int64, parts: Int32, name: String, md5Checksum: String)
        case inputFileBig(id: Int64, parts: Int32, name: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputFile(let id, let parts, let name, let md5Checksum):
                    if boxed {
                        buffer.appendInt32(-181407105)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    break
                case .inputFileBig(let id, let parts, let name):
                    if boxed {
                        buffer.appendInt32(-95482955)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputFile(let id, let parts, let name, let md5Checksum):
                return ("inputFile", [("id", id), ("parts", parts), ("name", name), ("md5Checksum", md5Checksum)])
                case .inputFileBig(let id, let parts, let name):
                return ("inputFileBig", [("id", id), ("parts", parts), ("name", name)])
    }
    }
    
        public static func parse_inputFile(_ reader: BufferReader) -> InputFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFile.inputFile(id: _1!, parts: _2!, name: _3!, md5Checksum: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileBig(_ reader: BufferReader) -> InputFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFile.inputFileBig(id: _1!, parts: _2!, name: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Peer: TypeConstructorDescription {
        case peerUser(userId: Int32)
        case peerChat(chatId: Int32)
        case peerChannel(channelId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerUser(let userId):
                    if boxed {
                        buffer.appendInt32(-1649296275)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .peerChat(let chatId):
                    if boxed {
                        buffer.appendInt32(-1160714821)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .peerChannel(let channelId):
                    if boxed {
                        buffer.appendInt32(-1109531342)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerUser(let userId):
                return ("peerUser", [("userId", userId)])
                case .peerChat(let chatId):
                return ("peerChat", [("chatId", chatId)])
                case .peerChannel(let channelId):
                return ("peerChannel", [("channelId", channelId)])
    }
    }
    
        public static func parse_peerUser(_ reader: BufferReader) -> Peer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerUser(userId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerChat(_ reader: BufferReader) -> Peer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerChannel(_ reader: BufferReader) -> Peer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerChannel(channelId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentRequestedInfo: TypeConstructorDescription {
        case paymentRequestedInfo(flags: Int32, name: String?, phone: String?, email: String?, shippingAddress: Api.PostAddress?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentRequestedInfo(let flags, let name, let phone, let email, let shippingAddress):
                    if boxed {
                        buffer.appendInt32(-1868808300)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(name!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(phone!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {shippingAddress!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentRequestedInfo(let flags, let name, let phone, let email, let shippingAddress):
                return ("paymentRequestedInfo", [("flags", flags), ("name", name), ("phone", phone), ("email", email), ("shippingAddress", shippingAddress)])
    }
    }
    
        public static func parse_paymentRequestedInfo(_ reader: BufferReader) -> PaymentRequestedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: Api.PostAddress?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PostAddress
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PaymentRequestedInfo.paymentRequestedInfo(flags: _1!, name: _2, phone: _3, email: _4, shippingAddress: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum UserStatus: TypeConstructorDescription {
        case userStatusEmpty
        case userStatusOnline(expires: Int32)
        case userStatusOffline(wasOnline: Int32)
        case userStatusRecently
        case userStatusLastWeek
        case userStatusLastMonth
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userStatusEmpty:
                    if boxed {
                        buffer.appendInt32(164646985)
                    }
                    
                    break
                case .userStatusOnline(let expires):
                    if boxed {
                        buffer.appendInt32(-306628279)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
                case .userStatusOffline(let wasOnline):
                    if boxed {
                        buffer.appendInt32(9203775)
                    }
                    serializeInt32(wasOnline, buffer: buffer, boxed: false)
                    break
                case .userStatusRecently:
                    if boxed {
                        buffer.appendInt32(-496024847)
                    }
                    
                    break
                case .userStatusLastWeek:
                    if boxed {
                        buffer.appendInt32(129960444)
                    }
                    
                    break
                case .userStatusLastMonth:
                    if boxed {
                        buffer.appendInt32(2011940674)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userStatusEmpty:
                return ("userStatusEmpty", [])
                case .userStatusOnline(let expires):
                return ("userStatusOnline", [("expires", expires)])
                case .userStatusOffline(let wasOnline):
                return ("userStatusOffline", [("wasOnline", wasOnline)])
                case .userStatusRecently:
                return ("userStatusRecently", [])
                case .userStatusLastWeek:
                return ("userStatusLastWeek", [])
                case .userStatusLastMonth:
                return ("userStatusLastMonth", [])
    }
    }
    
        public static func parse_userStatusEmpty(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusEmpty
        }
        public static func parse_userStatusOnline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusOnline(expires: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusOffline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusOffline(wasOnline: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusRecently(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusRecently
        }
        public static func parse_userStatusLastWeek(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusLastWeek
        }
        public static func parse_userStatusLastMonth(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusLastMonth
        }
    
    }
    public enum Folder: TypeConstructorDescription {
        case folder(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .folder(let flags, let id, let title, let photo):
                    if boxed {
                        buffer.appendInt32(-11252123)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {photo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .folder(let flags, let id, let title, let photo):
                return ("folder", [("flags", flags), ("id", id), ("title", title), ("photo", photo)])
    }
    }
    
        public static func parse_folder(_ reader: BufferReader) -> Folder? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatPhoto?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Folder.folder(flags: _1!, id: _2!, title: _3!, photo: _4)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Dialog: TypeConstructorDescription {
        case dialog(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, notifySettings: Api.PeerNotifySettings, pts: Int32?, draft: Api.DraftMessage?, folderId: Int32?)
        case dialogFolder(flags: Int32, folder: Api.Folder, peer: Api.Peer, topMessage: Int32, unreadMutedPeersCount: Int32, unreadUnmutedPeersCount: Int32, unreadMutedMessagesCount: Int32, unreadUnmutedMessagesCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialog(let flags, let peer, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let notifySettings, let pts, let draft, let folderId):
                    if boxed {
                        buffer.appendInt32(739712882)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadMentionsCount, buffer: buffer, boxed: false)
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(pts!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {draft!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    break
                case .dialogFolder(let flags, let folder, let peer, let topMessage, let unreadMutedPeersCount, let unreadUnmutedPeersCount, let unreadMutedMessagesCount, let unreadUnmutedMessagesCount):
                    if boxed {
                        buffer.appendInt32(1908216652)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    folder.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(unreadMutedPeersCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadUnmutedPeersCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadMutedMessagesCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadUnmutedMessagesCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dialog(let flags, let peer, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let notifySettings, let pts, let draft, let folderId):
                return ("dialog", [("flags", flags), ("peer", peer), ("topMessage", topMessage), ("readInboxMaxId", readInboxMaxId), ("readOutboxMaxId", readOutboxMaxId), ("unreadCount", unreadCount), ("unreadMentionsCount", unreadMentionsCount), ("notifySettings", notifySettings), ("pts", pts), ("draft", draft), ("folderId", folderId)])
                case .dialogFolder(let flags, let folder, let peer, let topMessage, let unreadMutedPeersCount, let unreadUnmutedPeersCount, let unreadMutedMessagesCount, let unreadUnmutedMessagesCount):
                return ("dialogFolder", [("flags", flags), ("folder", folder), ("peer", peer), ("topMessage", topMessage), ("unreadMutedPeersCount", unreadMutedPeersCount), ("unreadUnmutedPeersCount", unreadUnmutedPeersCount), ("unreadMutedMessagesCount", unreadMutedMessagesCount), ("unreadUnmutedMessagesCount", unreadUnmutedMessagesCount)])
    }
    }
    
        public static func parse_dialog(_ reader: BufferReader) -> Dialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_9 = reader.readInt32() }
            var _10: Api.DraftMessage?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            } }
            var _11: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_11 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 4) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.Dialog.dialog(flags: _1!, peer: _2!, topMessage: _3!, readInboxMaxId: _4!, readOutboxMaxId: _5!, unreadCount: _6!, unreadMentionsCount: _7!, notifySettings: _8!, pts: _9, draft: _10, folderId: _11)
            }
            else {
                return nil
            }
        }
        public static func parse_dialogFolder(_ reader: BufferReader) -> Dialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Folder?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Folder
            }
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
            var _8: Int32?
            _8 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Dialog.dialogFolder(flags: _1!, folder: _2!, peer: _3!, topMessage: _4!, unreadMutedPeersCount: _5!, unreadUnmutedPeersCount: _6!, unreadMutedMessagesCount: _7!, unreadUnmutedMessagesCount: _8!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SendMessageAction: TypeConstructorDescription {
        case sendMessageTypingAction
        case sendMessageCancelAction
        case sendMessageRecordVideoAction
        case sendMessageUploadVideoAction(progress: Int32)
        case sendMessageRecordAudioAction
        case sendMessageUploadAudioAction(progress: Int32)
        case sendMessageUploadPhotoAction(progress: Int32)
        case sendMessageUploadDocumentAction(progress: Int32)
        case sendMessageGeoLocationAction
        case sendMessageChooseContactAction
        case sendMessageGamePlayAction
        case sendMessageRecordRoundAction
        case sendMessageUploadRoundAction(progress: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sendMessageTypingAction:
                    if boxed {
                        buffer.appendInt32(381645902)
                    }
                    
                    break
                case .sendMessageCancelAction:
                    if boxed {
                        buffer.appendInt32(-44119819)
                    }
                    
                    break
                case .sendMessageRecordVideoAction:
                    if boxed {
                        buffer.appendInt32(-1584933265)
                    }
                    
                    break
                case .sendMessageUploadVideoAction(let progress):
                    if boxed {
                        buffer.appendInt32(-378127636)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageRecordAudioAction:
                    if boxed {
                        buffer.appendInt32(-718310409)
                    }
                    
                    break
                case .sendMessageUploadAudioAction(let progress):
                    if boxed {
                        buffer.appendInt32(-212740181)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadPhotoAction(let progress):
                    if boxed {
                        buffer.appendInt32(-774682074)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadDocumentAction(let progress):
                    if boxed {
                        buffer.appendInt32(-1441998364)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageGeoLocationAction:
                    if boxed {
                        buffer.appendInt32(393186209)
                    }
                    
                    break
                case .sendMessageChooseContactAction:
                    if boxed {
                        buffer.appendInt32(1653390447)
                    }
                    
                    break
                case .sendMessageGamePlayAction:
                    if boxed {
                        buffer.appendInt32(-580219064)
                    }
                    
                    break
                case .sendMessageRecordRoundAction:
                    if boxed {
                        buffer.appendInt32(-1997373508)
                    }
                    
                    break
                case .sendMessageUploadRoundAction(let progress):
                    if boxed {
                        buffer.appendInt32(608050278)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sendMessageTypingAction:
                return ("sendMessageTypingAction", [])
                case .sendMessageCancelAction:
                return ("sendMessageCancelAction", [])
                case .sendMessageRecordVideoAction:
                return ("sendMessageRecordVideoAction", [])
                case .sendMessageUploadVideoAction(let progress):
                return ("sendMessageUploadVideoAction", [("progress", progress)])
                case .sendMessageRecordAudioAction:
                return ("sendMessageRecordAudioAction", [])
                case .sendMessageUploadAudioAction(let progress):
                return ("sendMessageUploadAudioAction", [("progress", progress)])
                case .sendMessageUploadPhotoAction(let progress):
                return ("sendMessageUploadPhotoAction", [("progress", progress)])
                case .sendMessageUploadDocumentAction(let progress):
                return ("sendMessageUploadDocumentAction", [("progress", progress)])
                case .sendMessageGeoLocationAction:
                return ("sendMessageGeoLocationAction", [])
                case .sendMessageChooseContactAction:
                return ("sendMessageChooseContactAction", [])
                case .sendMessageGamePlayAction:
                return ("sendMessageGamePlayAction", [])
                case .sendMessageRecordRoundAction:
                return ("sendMessageRecordRoundAction", [])
                case .sendMessageUploadRoundAction(let progress):
                return ("sendMessageUploadRoundAction", [("progress", progress)])
    }
    }
    
        public static func parse_sendMessageTypingAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageTypingAction
        }
        public static func parse_sendMessageCancelAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageCancelAction
        }
        public static func parse_sendMessageRecordVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordVideoAction
        }
        public static func parse_sendMessageUploadVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadVideoAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageRecordAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordAudioAction
        }
        public static func parse_sendMessageUploadAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadAudioAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageUploadPhotoAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageUploadDocumentAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageGeoLocationAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageGeoLocationAction
        }
        public static func parse_sendMessageChooseContactAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageChooseContactAction
        }
        public static func parse_sendMessageGamePlayAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageGamePlayAction
        }
        public static func parse_sendMessageRecordRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordRoundAction
        }
        public static func parse_sendMessageUploadRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadRoundAction(progress: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PrivacyKey: TypeConstructorDescription {
        case privacyKeyStatusTimestamp
        case privacyKeyChatInvite
        case privacyKeyPhoneCall
        case privacyKeyPhoneP2P
        case privacyKeyForwards
        case privacyKeyProfilePhoto
        case privacyKeyPhoneNumber
        case privacyKeyAddedByPhone
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyKeyStatusTimestamp:
                    if boxed {
                        buffer.appendInt32(-1137792208)
                    }
                    
                    break
                case .privacyKeyChatInvite:
                    if boxed {
                        buffer.appendInt32(1343122938)
                    }
                    
                    break
                case .privacyKeyPhoneCall:
                    if boxed {
                        buffer.appendInt32(1030105979)
                    }
                    
                    break
                case .privacyKeyPhoneP2P:
                    if boxed {
                        buffer.appendInt32(961092808)
                    }
                    
                    break
                case .privacyKeyForwards:
                    if boxed {
                        buffer.appendInt32(1777096355)
                    }
                    
                    break
                case .privacyKeyProfilePhoto:
                    if boxed {
                        buffer.appendInt32(-1777000467)
                    }
                    
                    break
                case .privacyKeyPhoneNumber:
                    if boxed {
                        buffer.appendInt32(-778378131)
                    }
                    
                    break
                case .privacyKeyAddedByPhone:
                    if boxed {
                        buffer.appendInt32(1124062251)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .privacyKeyStatusTimestamp:
                return ("privacyKeyStatusTimestamp", [])
                case .privacyKeyChatInvite:
                return ("privacyKeyChatInvite", [])
                case .privacyKeyPhoneCall:
                return ("privacyKeyPhoneCall", [])
                case .privacyKeyPhoneP2P:
                return ("privacyKeyPhoneP2P", [])
                case .privacyKeyForwards:
                return ("privacyKeyForwards", [])
                case .privacyKeyProfilePhoto:
                return ("privacyKeyProfilePhoto", [])
                case .privacyKeyPhoneNumber:
                return ("privacyKeyPhoneNumber", [])
                case .privacyKeyAddedByPhone:
                return ("privacyKeyAddedByPhone", [])
    }
    }
    
        public static func parse_privacyKeyStatusTimestamp(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyStatusTimestamp
        }
        public static func parse_privacyKeyChatInvite(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyChatInvite
        }
        public static func parse_privacyKeyPhoneCall(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyPhoneCall
        }
        public static func parse_privacyKeyPhoneP2P(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyPhoneP2P
        }
        public static func parse_privacyKeyForwards(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyForwards
        }
        public static func parse_privacyKeyProfilePhoto(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyProfilePhoto
        }
        public static func parse_privacyKeyPhoneNumber(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyPhoneNumber
        }
        public static func parse_privacyKeyAddedByPhone(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyAddedByPhone
        }
    
    }
    public enum Update: TypeConstructorDescription {
        case updateNewMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateMessageID(id: Int32, randomId: Int64)
        case updateDeleteMessages(messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateUserTyping(userId: Int32, action: Api.SendMessageAction)
        case updateChatUserTyping(chatId: Int32, userId: Int32, action: Api.SendMessageAction)
        case updateChatParticipants(participants: Api.ChatParticipants)
        case updateUserStatus(userId: Int32, status: Api.UserStatus)
        case updateUserName(userId: Int32, firstName: String, lastName: String, username: String)
        case updateUserPhoto(userId: Int32, date: Int32, photo: Api.UserProfilePhoto, previous: Api.Bool)
        case updateNewEncryptedMessage(message: Api.EncryptedMessage, qts: Int32)
        case updateEncryptedChatTyping(chatId: Int32)
        case updateEncryption(chat: Api.EncryptedChat, date: Int32)
        case updateEncryptedMessagesRead(chatId: Int32, maxDate: Int32, date: Int32)
        case updateChatParticipantAdd(chatId: Int32, userId: Int32, inviterId: Int32, date: Int32, version: Int32)
        case updateChatParticipantDelete(chatId: Int32, userId: Int32, version: Int32)
        case updateDcOptions(dcOptions: [Api.DcOption])
        case updateUserBlocked(userId: Int32, blocked: Api.Bool)
        case updateNotifySettings(peer: Api.NotifyPeer, notifySettings: Api.PeerNotifySettings)
        case updateServiceNotification(flags: Int32, inboxDate: Int32?, type: String, message: String, media: Api.MessageMedia, entities: [Api.MessageEntity])
        case updatePrivacy(key: Api.PrivacyKey, rules: [Api.PrivacyRule])
        case updateUserPhone(userId: Int32, phone: String)
        case updateReadHistoryOutbox(peer: Api.Peer, maxId: Int32, pts: Int32, ptsCount: Int32)
        case updateWebPage(webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateReadMessagesContents(messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateChannelTooLong(flags: Int32, channelId: Int32, pts: Int32?)
        case updateChannel(channelId: Int32)
        case updateNewChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateDeleteChannelMessages(channelId: Int32, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateChannelMessageViews(channelId: Int32, id: Int32, views: Int32)
        case updateChatParticipantAdmin(chatId: Int32, userId: Int32, isAdmin: Api.Bool, version: Int32)
        case updateNewStickerSet(stickerset: Api.messages.StickerSet)
        case updateStickerSetsOrder(flags: Int32, order: [Int64])
        case updateStickerSets
        case updateSavedGifs
        case updateBotInlineQuery(flags: Int32, queryId: Int64, userId: Int32, query: String, geo: Api.GeoPoint?, offset: String)
        case updateBotInlineSend(flags: Int32, userId: Int32, query: String, geo: Api.GeoPoint?, id: String, msgId: Api.InputBotInlineMessageID?)
        case updateEditChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateChannelPinnedMessage(channelId: Int32, id: Int32)
        case updateBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int32, peer: Api.Peer, msgId: Int32, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateEditMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateInlineBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int32, msgId: Api.InputBotInlineMessageID, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateReadChannelOutbox(channelId: Int32, maxId: Int32)
        case updateDraftMessage(peer: Api.Peer, draft: Api.DraftMessage)
        case updateReadFeaturedStickers
        case updateRecentStickers
        case updateConfig
        case updatePtsChanged
        case updateChannelWebPage(channelId: Int32, webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateBotWebhookJSON(data: Api.DataJSON)
        case updateBotWebhookJSONQuery(queryId: Int64, data: Api.DataJSON, timeout: Int32)
        case updateBotShippingQuery(queryId: Int64, userId: Int32, payload: Buffer, shippingAddress: Api.PostAddress)
        case updateBotPrecheckoutQuery(flags: Int32, queryId: Int64, userId: Int32, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, currency: String, totalAmount: Int64)
        case updatePhoneCall(phoneCall: Api.PhoneCall)
        case updateLangPack(difference: Api.LangPackDifference)
        case updateFavedStickers
        case updateChannelReadMessagesContents(channelId: Int32, messages: [Int32])
        case updateContactsReset
        case updateChannelAvailableMessages(channelId: Int32, availableMinId: Int32)
        case updateDialogUnreadMark(flags: Int32, peer: Api.DialogPeer)
        case updateLangPackTooLong(langCode: String)
        case updateUserPinnedMessage(userId: Int32, id: Int32)
        case updateMessagePoll(flags: Int32, pollId: Int64, poll: Api.Poll?, results: Api.PollResults)
        case updateChatDefaultBannedRights(peer: Api.Peer, defaultBannedRights: Api.ChatBannedRights, version: Int32)
        case updateChatPinnedMessage(chatId: Int32, id: Int32, version: Int32)
        case updateFolderPeers(folderPeers: [Api.FolderPeer], pts: Int32, ptsCount: Int32)
        case updateDialogPinned(flags: Int32, folderId: Int32?, peer: Api.DialogPeer)
        case updatePinnedDialogs(flags: Int32, folderId: Int32?, order: [Api.DialogPeer]?)
        case updateReadChannelInbox(flags: Int32, folderId: Int32?, channelId: Int32, maxId: Int32, stillUnreadCount: Int32, pts: Int32)
        case updateReadHistoryInbox(flags: Int32, folderId: Int32?, peer: Api.Peer, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32)
        case updatePeerSettings(peer: Api.Peer, settings: Api.PeerSettings)
        case updatePeerLocated(peers: [Api.PeerLocated])
        case updateNewScheduledMessage(message: Api.Message)
        case updateDeleteScheduledMessages(peer: Api.Peer, messages: [Int32])
        case updateTheme(theme: Api.Theme)
        case updateGeoLiveViewed(peer: Api.Peer, msgId: Int32)
        case updateLoginToken
        case updateMessagePollVote(pollId: Int64, userId: Int32, options: [Buffer])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .updateNewMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(522914557)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateMessageID(let id, let randomId):
                    if boxed {
                        buffer.appendInt32(1318109142)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
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
                case .updateUserTyping(let userId, let action):
                    if boxed {
                        buffer.appendInt32(1548249383)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
                case .updateChatUserTyping(let chatId, let userId, let action):
                    if boxed {
                        buffer.appendInt32(-1704596961)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
                case .updateChatParticipants(let participants):
                    if boxed {
                        buffer.appendInt32(125178264)
                    }
                    participants.serialize(buffer, true)
                    break
                case .updateUserStatus(let userId, let status):
                    if boxed {
                        buffer.appendInt32(469489699)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    status.serialize(buffer, true)
                    break
                case .updateUserName(let userId, let firstName, let lastName, let username):
                    if boxed {
                        buffer.appendInt32(-1489818765)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(username, buffer: buffer, boxed: false)
                    break
                case .updateUserPhoto(let userId, let date, let photo, let previous):
                    if boxed {
                        buffer.appendInt32(-1791935732)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    previous.serialize(buffer, true)
                    break
                case .updateNewEncryptedMessage(let message, let qts):
                    if boxed {
                        buffer.appendInt32(314359194)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateEncryptedChatTyping(let chatId):
                    if boxed {
                        buffer.appendInt32(386986326)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .updateEncryption(let chat, let date):
                    if boxed {
                        buffer.appendInt32(-1264392051)
                    }
                    chat.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateEncryptedMessagesRead(let chatId, let maxDate, let date):
                    if boxed {
                        buffer.appendInt32(956179895)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantAdd(let chatId, let userId, let inviterId, let date, let version):
                    if boxed {
                        buffer.appendInt32(-364179876)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantDelete(let chatId, let userId, let version):
                    if boxed {
                        buffer.appendInt32(1851755554)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
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
                case .updateUserBlocked(let userId, let blocked):
                    if boxed {
                        buffer.appendInt32(-2131957734)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    blocked.serialize(buffer, true)
                    break
                case .updateNotifySettings(let peer, let notifySettings):
                    if boxed {
                        buffer.appendInt32(-1094555409)
                    }
                    peer.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
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
                case .updateUserPhone(let userId, let phone):
                    if boxed {
                        buffer.appendInt32(314130811)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
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
                case .updateWebPage(let webpage, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(2139689491)
                    }
                    webpage.serialize(buffer, true)
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
                case .updateChannelTooLong(let flags, let channelId, let pts):
                    if boxed {
                        buffer.appendInt32(-352032773)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(pts!, buffer: buffer, boxed: false)}
                    break
                case .updateChannel(let channelId):
                    if boxed {
                        buffer.appendInt32(-1227598250)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    break
                case .updateNewChannelMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1656358105)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateDeleteChannelMessages(let channelId, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1015733815)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateChannelMessageViews(let channelId, let id, let views):
                    if boxed {
                        buffer.appendInt32(-1734268085)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantAdmin(let chatId, let userId, let isAdmin, let version):
                    if boxed {
                        buffer.appendInt32(-1232070311)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    isAdmin.serialize(buffer, true)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateNewStickerSet(let stickerset):
                    if boxed {
                        buffer.appendInt32(1753886890)
                    }
                    stickerset.serialize(buffer, true)
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
                case .updateStickerSets:
                    if boxed {
                        buffer.appendInt32(1135492588)
                    }
                    
                    break
                case .updateSavedGifs:
                    if boxed {
                        buffer.appendInt32(-1821035490)
                    }
                    
                    break
                case .updateBotInlineQuery(let flags, let queryId, let userId, let query, let geo, let offset):
                    if boxed {
                        buffer.appendInt32(1417832080)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geo!.serialize(buffer, true)}
                    serializeString(offset, buffer: buffer, boxed: false)
                    break
                case .updateBotInlineSend(let flags, let userId, let query, let geo, let id, let msgId):
                    if boxed {
                        buffer.appendInt32(239663460)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geo!.serialize(buffer, true)}
                    serializeString(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {msgId!.serialize(buffer, true)}
                    break
                case .updateEditChannelMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(457133559)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateChannelPinnedMessage(let channelId, let id):
                    if boxed {
                        buffer.appendInt32(-1738988427)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .updateBotCallbackQuery(let flags, let queryId, let userId, let peer, let msgId, let chatInstance, let data, let gameShortName):
                    if boxed {
                        buffer.appendInt32(-415938591)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(gameShortName!, buffer: buffer, boxed: false)}
                    break
                case .updateEditMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-469536605)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateInlineBotCallbackQuery(let flags, let queryId, let userId, let msgId, let chatInstance, let data, let gameShortName):
                    if boxed {
                        buffer.appendInt32(-103646630)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    msgId.serialize(buffer, true)
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(gameShortName!, buffer: buffer, boxed: false)}
                    break
                case .updateReadChannelOutbox(let channelId, let maxId):
                    if boxed {
                        buffer.appendInt32(634833351)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    break
                case .updateDraftMessage(let peer, let draft):
                    if boxed {
                        buffer.appendInt32(-299124375)
                    }
                    peer.serialize(buffer, true)
                    draft.serialize(buffer, true)
                    break
                case .updateReadFeaturedStickers:
                    if boxed {
                        buffer.appendInt32(1461528386)
                    }
                    
                    break
                case .updateRecentStickers:
                    if boxed {
                        buffer.appendInt32(-1706939360)
                    }
                    
                    break
                case .updateConfig:
                    if boxed {
                        buffer.appendInt32(-1574314746)
                    }
                    
                    break
                case .updatePtsChanged:
                    if boxed {
                        buffer.appendInt32(861169551)
                    }
                    
                    break
                case .updateChannelWebPage(let channelId, let webpage, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1081547008)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    webpage.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
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
                case .updateBotShippingQuery(let queryId, let userId, let payload, let shippingAddress):
                    if boxed {
                        buffer.appendInt32(-523384512)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    shippingAddress.serialize(buffer, true)
                    break
                case .updateBotPrecheckoutQuery(let flags, let queryId, let userId, let payload, let info, let shippingOptionId, let currency, let totalAmount):
                    if boxed {
                        buffer.appendInt32(1563376297)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    break
                case .updatePhoneCall(let phoneCall):
                    if boxed {
                        buffer.appendInt32(-1425052898)
                    }
                    phoneCall.serialize(buffer, true)
                    break
                case .updateLangPack(let difference):
                    if boxed {
                        buffer.appendInt32(1442983757)
                    }
                    difference.serialize(buffer, true)
                    break
                case .updateFavedStickers:
                    if boxed {
                        buffer.appendInt32(-451831443)
                    }
                    
                    break
                case .updateChannelReadMessagesContents(let channelId, let messages):
                    if boxed {
                        buffer.appendInt32(-1987495099)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateContactsReset:
                    if boxed {
                        buffer.appendInt32(1887741886)
                    }
                    
                    break
                case .updateChannelAvailableMessages(let channelId, let availableMinId):
                    if boxed {
                        buffer.appendInt32(1893427255)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt32(availableMinId, buffer: buffer, boxed: false)
                    break
                case .updateDialogUnreadMark(let flags, let peer):
                    if boxed {
                        buffer.appendInt32(-513517117)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    break
                case .updateLangPackTooLong(let langCode):
                    if boxed {
                        buffer.appendInt32(1180041828)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    break
                case .updateUserPinnedMessage(let userId, let id):
                    if boxed {
                        buffer.appendInt32(1279515160)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
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
                case .updateChatDefaultBannedRights(let peer, let defaultBannedRights, let version):
                    if boxed {
                        buffer.appendInt32(1421875280)
                    }
                    peer.serialize(buffer, true)
                    defaultBannedRights.serialize(buffer, true)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatPinnedMessage(let chatId, let id, let version):
                    if boxed {
                        buffer.appendInt32(-519195831)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
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
                case .updateDialogPinned(let flags, let folderId, let peer):
                    if boxed {
                        buffer.appendInt32(1852826908)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
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
                case .updateReadChannelInbox(let flags, let folderId, let channelId, let maxId, let stillUnreadCount, let pts):
                    if boxed {
                        buffer.appendInt32(856380452)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(stillUnreadCount, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
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
                case .updatePeerSettings(let peer, let settings):
                    if boxed {
                        buffer.appendInt32(1786671974)
                    }
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
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
                case .updateNewScheduledMessage(let message):
                    if boxed {
                        buffer.appendInt32(967122427)
                    }
                    message.serialize(buffer, true)
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
                case .updateTheme(let theme):
                    if boxed {
                        buffer.appendInt32(-2112423005)
                    }
                    theme.serialize(buffer, true)
                    break
                case .updateGeoLiveViewed(let peer, let msgId):
                    if boxed {
                        buffer.appendInt32(-2027964103)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .updateLoginToken:
                    if boxed {
                        buffer.appendInt32(1448076945)
                    }
                    
                    break
                case .updateMessagePollVote(let pollId, let userId, let options):
                    if boxed {
                        buffer.appendInt32(1123585836)
                    }
                    serializeInt64(pollId, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .updateNewMessage(let message, let pts, let ptsCount):
                return ("updateNewMessage", [("message", message), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateMessageID(let id, let randomId):
                return ("updateMessageID", [("id", id), ("randomId", randomId)])
                case .updateDeleteMessages(let messages, let pts, let ptsCount):
                return ("updateDeleteMessages", [("messages", messages), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateUserTyping(let userId, let action):
                return ("updateUserTyping", [("userId", userId), ("action", action)])
                case .updateChatUserTyping(let chatId, let userId, let action):
                return ("updateChatUserTyping", [("chatId", chatId), ("userId", userId), ("action", action)])
                case .updateChatParticipants(let participants):
                return ("updateChatParticipants", [("participants", participants)])
                case .updateUserStatus(let userId, let status):
                return ("updateUserStatus", [("userId", userId), ("status", status)])
                case .updateUserName(let userId, let firstName, let lastName, let username):
                return ("updateUserName", [("userId", userId), ("firstName", firstName), ("lastName", lastName), ("username", username)])
                case .updateUserPhoto(let userId, let date, let photo, let previous):
                return ("updateUserPhoto", [("userId", userId), ("date", date), ("photo", photo), ("previous", previous)])
                case .updateNewEncryptedMessage(let message, let qts):
                return ("updateNewEncryptedMessage", [("message", message), ("qts", qts)])
                case .updateEncryptedChatTyping(let chatId):
                return ("updateEncryptedChatTyping", [("chatId", chatId)])
                case .updateEncryption(let chat, let date):
                return ("updateEncryption", [("chat", chat), ("date", date)])
                case .updateEncryptedMessagesRead(let chatId, let maxDate, let date):
                return ("updateEncryptedMessagesRead", [("chatId", chatId), ("maxDate", maxDate), ("date", date)])
                case .updateChatParticipantAdd(let chatId, let userId, let inviterId, let date, let version):
                return ("updateChatParticipantAdd", [("chatId", chatId), ("userId", userId), ("inviterId", inviterId), ("date", date), ("version", version)])
                case .updateChatParticipantDelete(let chatId, let userId, let version):
                return ("updateChatParticipantDelete", [("chatId", chatId), ("userId", userId), ("version", version)])
                case .updateDcOptions(let dcOptions):
                return ("updateDcOptions", [("dcOptions", dcOptions)])
                case .updateUserBlocked(let userId, let blocked):
                return ("updateUserBlocked", [("userId", userId), ("blocked", blocked)])
                case .updateNotifySettings(let peer, let notifySettings):
                return ("updateNotifySettings", [("peer", peer), ("notifySettings", notifySettings)])
                case .updateServiceNotification(let flags, let inboxDate, let type, let message, let media, let entities):
                return ("updateServiceNotification", [("flags", flags), ("inboxDate", inboxDate), ("type", type), ("message", message), ("media", media), ("entities", entities)])
                case .updatePrivacy(let key, let rules):
                return ("updatePrivacy", [("key", key), ("rules", rules)])
                case .updateUserPhone(let userId, let phone):
                return ("updateUserPhone", [("userId", userId), ("phone", phone)])
                case .updateReadHistoryOutbox(let peer, let maxId, let pts, let ptsCount):
                return ("updateReadHistoryOutbox", [("peer", peer), ("maxId", maxId), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateWebPage(let webpage, let pts, let ptsCount):
                return ("updateWebPage", [("webpage", webpage), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateReadMessagesContents(let messages, let pts, let ptsCount):
                return ("updateReadMessagesContents", [("messages", messages), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateChannelTooLong(let flags, let channelId, let pts):
                return ("updateChannelTooLong", [("flags", flags), ("channelId", channelId), ("pts", pts)])
                case .updateChannel(let channelId):
                return ("updateChannel", [("channelId", channelId)])
                case .updateNewChannelMessage(let message, let pts, let ptsCount):
                return ("updateNewChannelMessage", [("message", message), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateDeleteChannelMessages(let channelId, let messages, let pts, let ptsCount):
                return ("updateDeleteChannelMessages", [("channelId", channelId), ("messages", messages), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateChannelMessageViews(let channelId, let id, let views):
                return ("updateChannelMessageViews", [("channelId", channelId), ("id", id), ("views", views)])
                case .updateChatParticipantAdmin(let chatId, let userId, let isAdmin, let version):
                return ("updateChatParticipantAdmin", [("chatId", chatId), ("userId", userId), ("isAdmin", isAdmin), ("version", version)])
                case .updateNewStickerSet(let stickerset):
                return ("updateNewStickerSet", [("stickerset", stickerset)])
                case .updateStickerSetsOrder(let flags, let order):
                return ("updateStickerSetsOrder", [("flags", flags), ("order", order)])
                case .updateStickerSets:
                return ("updateStickerSets", [])
                case .updateSavedGifs:
                return ("updateSavedGifs", [])
                case .updateBotInlineQuery(let flags, let queryId, let userId, let query, let geo, let offset):
                return ("updateBotInlineQuery", [("flags", flags), ("queryId", queryId), ("userId", userId), ("query", query), ("geo", geo), ("offset", offset)])
                case .updateBotInlineSend(let flags, let userId, let query, let geo, let id, let msgId):
                return ("updateBotInlineSend", [("flags", flags), ("userId", userId), ("query", query), ("geo", geo), ("id", id), ("msgId", msgId)])
                case .updateEditChannelMessage(let message, let pts, let ptsCount):
                return ("updateEditChannelMessage", [("message", message), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateChannelPinnedMessage(let channelId, let id):
                return ("updateChannelPinnedMessage", [("channelId", channelId), ("id", id)])
                case .updateBotCallbackQuery(let flags, let queryId, let userId, let peer, let msgId, let chatInstance, let data, let gameShortName):
                return ("updateBotCallbackQuery", [("flags", flags), ("queryId", queryId), ("userId", userId), ("peer", peer), ("msgId", msgId), ("chatInstance", chatInstance), ("data", data), ("gameShortName", gameShortName)])
                case .updateEditMessage(let message, let pts, let ptsCount):
                return ("updateEditMessage", [("message", message), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateInlineBotCallbackQuery(let flags, let queryId, let userId, let msgId, let chatInstance, let data, let gameShortName):
                return ("updateInlineBotCallbackQuery", [("flags", flags), ("queryId", queryId), ("userId", userId), ("msgId", msgId), ("chatInstance", chatInstance), ("data", data), ("gameShortName", gameShortName)])
                case .updateReadChannelOutbox(let channelId, let maxId):
                return ("updateReadChannelOutbox", [("channelId", channelId), ("maxId", maxId)])
                case .updateDraftMessage(let peer, let draft):
                return ("updateDraftMessage", [("peer", peer), ("draft", draft)])
                case .updateReadFeaturedStickers:
                return ("updateReadFeaturedStickers", [])
                case .updateRecentStickers:
                return ("updateRecentStickers", [])
                case .updateConfig:
                return ("updateConfig", [])
                case .updatePtsChanged:
                return ("updatePtsChanged", [])
                case .updateChannelWebPage(let channelId, let webpage, let pts, let ptsCount):
                return ("updateChannelWebPage", [("channelId", channelId), ("webpage", webpage), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateBotWebhookJSON(let data):
                return ("updateBotWebhookJSON", [("data", data)])
                case .updateBotWebhookJSONQuery(let queryId, let data, let timeout):
                return ("updateBotWebhookJSONQuery", [("queryId", queryId), ("data", data), ("timeout", timeout)])
                case .updateBotShippingQuery(let queryId, let userId, let payload, let shippingAddress):
                return ("updateBotShippingQuery", [("queryId", queryId), ("userId", userId), ("payload", payload), ("shippingAddress", shippingAddress)])
                case .updateBotPrecheckoutQuery(let flags, let queryId, let userId, let payload, let info, let shippingOptionId, let currency, let totalAmount):
                return ("updateBotPrecheckoutQuery", [("flags", flags), ("queryId", queryId), ("userId", userId), ("payload", payload), ("info", info), ("shippingOptionId", shippingOptionId), ("currency", currency), ("totalAmount", totalAmount)])
                case .updatePhoneCall(let phoneCall):
                return ("updatePhoneCall", [("phoneCall", phoneCall)])
                case .updateLangPack(let difference):
                return ("updateLangPack", [("difference", difference)])
                case .updateFavedStickers:
                return ("updateFavedStickers", [])
                case .updateChannelReadMessagesContents(let channelId, let messages):
                return ("updateChannelReadMessagesContents", [("channelId", channelId), ("messages", messages)])
                case .updateContactsReset:
                return ("updateContactsReset", [])
                case .updateChannelAvailableMessages(let channelId, let availableMinId):
                return ("updateChannelAvailableMessages", [("channelId", channelId), ("availableMinId", availableMinId)])
                case .updateDialogUnreadMark(let flags, let peer):
                return ("updateDialogUnreadMark", [("flags", flags), ("peer", peer)])
                case .updateLangPackTooLong(let langCode):
                return ("updateLangPackTooLong", [("langCode", langCode)])
                case .updateUserPinnedMessage(let userId, let id):
                return ("updateUserPinnedMessage", [("userId", userId), ("id", id)])
                case .updateMessagePoll(let flags, let pollId, let poll, let results):
                return ("updateMessagePoll", [("flags", flags), ("pollId", pollId), ("poll", poll), ("results", results)])
                case .updateChatDefaultBannedRights(let peer, let defaultBannedRights, let version):
                return ("updateChatDefaultBannedRights", [("peer", peer), ("defaultBannedRights", defaultBannedRights), ("version", version)])
                case .updateChatPinnedMessage(let chatId, let id, let version):
                return ("updateChatPinnedMessage", [("chatId", chatId), ("id", id), ("version", version)])
                case .updateFolderPeers(let folderPeers, let pts, let ptsCount):
                return ("updateFolderPeers", [("folderPeers", folderPeers), ("pts", pts), ("ptsCount", ptsCount)])
                case .updateDialogPinned(let flags, let folderId, let peer):
                return ("updateDialogPinned", [("flags", flags), ("folderId", folderId), ("peer", peer)])
                case .updatePinnedDialogs(let flags, let folderId, let order):
                return ("updatePinnedDialogs", [("flags", flags), ("folderId", folderId), ("order", order)])
                case .updateReadChannelInbox(let flags, let folderId, let channelId, let maxId, let stillUnreadCount, let pts):
                return ("updateReadChannelInbox", [("flags", flags), ("folderId", folderId), ("channelId", channelId), ("maxId", maxId), ("stillUnreadCount", stillUnreadCount), ("pts", pts)])
                case .updateReadHistoryInbox(let flags, let folderId, let peer, let maxId, let stillUnreadCount, let pts, let ptsCount):
                return ("updateReadHistoryInbox", [("flags", flags), ("folderId", folderId), ("peer", peer), ("maxId", maxId), ("stillUnreadCount", stillUnreadCount), ("pts", pts), ("ptsCount", ptsCount)])
                case .updatePeerSettings(let peer, let settings):
                return ("updatePeerSettings", [("peer", peer), ("settings", settings)])
                case .updatePeerLocated(let peers):
                return ("updatePeerLocated", [("peers", peers)])
                case .updateNewScheduledMessage(let message):
                return ("updateNewScheduledMessage", [("message", message)])
                case .updateDeleteScheduledMessages(let peer, let messages):
                return ("updateDeleteScheduledMessages", [("peer", peer), ("messages", messages)])
                case .updateTheme(let theme):
                return ("updateTheme", [("theme", theme)])
                case .updateGeoLiveViewed(let peer, let msgId):
                return ("updateGeoLiveViewed", [("peer", peer), ("msgId", msgId)])
                case .updateLoginToken:
                return ("updateLoginToken", [])
                case .updateMessagePollVote(let pollId, let userId, let options):
                return ("updateMessagePollVote", [("pollId", pollId), ("userId", userId), ("options", options)])
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
        public static func parse_updateUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateChatUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatUserTyping(chatId: _1!, userId: _2!, action: _3!)
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
        public static func parse_updateUserStatus(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateUserName(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateUserPhoto(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateChatParticipantAdd(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
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
                return Api.Update.updateChatParticipantAdd(chatId: _1!, userId: _2!, inviterId: _3!, date: _4!, version: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantDelete(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateChatParticipantDelete(chatId: _1!, userId: _2!, version: _3!)
            }
            else {
                return nil
            }
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
        public static func parse_updateUserBlocked(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserBlocked(userId: _1!, blocked: _2!)
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
        public static func parse_updateUserPhone(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateChannelTooLong(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
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
        public static func parse_updateChannel(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChannel(channelId: _1!)
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
        public static func parse_updateDeleteChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateChannelMessageViews(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateChannelMessageViews(channelId: _1!, id: _2!, views: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdmin(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.Update.updateChatParticipantAdmin(chatId: _1!, userId: _2!, isAdmin: _3!, version: _4!)
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
        public static func parse_updateStickerSets(_ reader: BufferReader) -> Update? {
            return Api.Update.updateStickerSets
        }
        public static func parse_updateSavedGifs(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedGifs
        }
        public static func parse_updateBotInlineQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            } }
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotInlineQuery(flags: _1!, queryId: _2!, userId: _3!, query: _4!, geo: _5, offset: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineSend(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
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
        public static func parse_updateChannelPinnedMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelPinnedMessage(channelId: _1!, id: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
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
        public static func parse_updateInlineBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
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
        public static func parse_updateReadChannelOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateReadFeaturedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateReadFeaturedStickers
        }
        public static func parse_updateRecentStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentStickers
        }
        public static func parse_updateConfig(_ reader: BufferReader) -> Update? {
            return Api.Update.updateConfig
        }
        public static func parse_updatePtsChanged(_ reader: BufferReader) -> Update? {
            return Api.Update.updatePtsChanged
        }
        public static func parse_updateChannelWebPage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateBotShippingQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
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
        public static func parse_updateBotPrecheckoutQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
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
        public static func parse_updateFavedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateFavedStickers
        }
        public static func parse_updateChannelReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateContactsReset(_ reader: BufferReader) -> Update? {
            return Api.Update.updateContactsReset
        }
        public static func parse_updateChannelAvailableMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
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
        public static func parse_updateUserPinnedMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserPinnedMessage(userId: _1!, id: _2!)
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
        public static func parse_updateChatPinnedMessage(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateChatPinnedMessage(chatId: _1!, id: _2!, version: _3!)
            }
            else {
                return nil
            }
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
        public static func parse_updateReadChannelInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            _3 = reader.readInt32()
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
        public static func parse_updateLoginToken(_ reader: BufferReader) -> Update? {
            return Api.Update.updateLoginToken
        }
        public static func parse_updateMessagePollVote(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Buffer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateMessagePollVote(pollId: _1!, userId: _2!, options: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PopularContact: TypeConstructorDescription {
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
                return ("popularContact", [("clientId", clientId), ("importers", importers)])
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
    public enum FolderPeer: TypeConstructorDescription {
        case folderPeer(peer: Api.Peer, folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .folderPeer(let peer, let folderId):
                    if boxed {
                        buffer.appendInt32(-373643672)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .folderPeer(let peer, let folderId):
                return ("folderPeer", [("peer", peer), ("folderId", folderId)])
    }
    }
    
        public static func parse_folderPeer(_ reader: BufferReader) -> FolderPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.FolderPeer.folderPeer(peer: _1!, folderId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelParticipant: TypeConstructorDescription {
        case channelParticipant(userId: Int32, date: Int32)
        case channelParticipantSelf(userId: Int32, inviterId: Int32, date: Int32)
        case channelParticipantBanned(flags: Int32, userId: Int32, kickedBy: Int32, date: Int32, bannedRights: Api.ChatBannedRights)
        case channelParticipantAdmin(flags: Int32, userId: Int32, inviterId: Int32?, promotedBy: Int32, date: Int32, adminRights: Api.ChatAdminRights, rank: String?)
        case channelParticipantCreator(flags: Int32, userId: Int32, rank: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipant(let userId, let date):
                    if boxed {
                        buffer.appendInt32(367766557)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .channelParticipantSelf(let userId, let inviterId, let date):
                    if boxed {
                        buffer.appendInt32(-1557620115)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .channelParticipantBanned(let flags, let userId, let kickedBy, let date, let bannedRights):
                    if boxed {
                        buffer.appendInt32(470789295)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(kickedBy, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    bannedRights.serialize(buffer, true)
                    break
                case .channelParticipantAdmin(let flags, let userId, let inviterId, let promotedBy, let date, let adminRights, let rank):
                    if boxed {
                        buffer.appendInt32(-859915345)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(inviterId!, buffer: buffer, boxed: false)}
                    serializeInt32(promotedBy, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    adminRights.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(rank!, buffer: buffer, boxed: false)}
                    break
                case .channelParticipantCreator(let flags, let userId, let rank):
                    if boxed {
                        buffer.appendInt32(-2138237532)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(rank!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelParticipant(let userId, let date):
                return ("channelParticipant", [("userId", userId), ("date", date)])
                case .channelParticipantSelf(let userId, let inviterId, let date):
                return ("channelParticipantSelf", [("userId", userId), ("inviterId", inviterId), ("date", date)])
                case .channelParticipantBanned(let flags, let userId, let kickedBy, let date, let bannedRights):
                return ("channelParticipantBanned", [("flags", flags), ("userId", userId), ("kickedBy", kickedBy), ("date", date), ("bannedRights", bannedRights)])
                case .channelParticipantAdmin(let flags, let userId, let inviterId, let promotedBy, let date, let adminRights, let rank):
                return ("channelParticipantAdmin", [("flags", flags), ("userId", userId), ("inviterId", inviterId), ("promotedBy", promotedBy), ("date", date), ("adminRights", adminRights), ("rank", rank)])
                case .channelParticipantCreator(let flags, let userId, let rank):
                return ("channelParticipantCreator", [("flags", flags), ("userId", userId), ("rank", rank)])
    }
    }
    
        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelParticipant.channelParticipant(userId: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantSelf(_ reader: BufferReader) -> ChannelParticipant? {
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
                return Api.ChannelParticipant.channelParticipantSelf(userId: _1!, inviterId: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantBanned(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChannelParticipant.channelParticipantBanned(flags: _1!, userId: _2!, kickedBy: _3!, date: _4!, bannedRights: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantAdmin(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.ChatAdminRights?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.ChannelParticipant.channelParticipantAdmin(flags: _1!, userId: _2!, inviterId: _3, promotedBy: _4!, date: _5!, adminRights: _6!, rank: _7)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantCreator(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelParticipant.channelParticipantCreator(flags: _1!, userId: _2!, rank: _3)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageUserVote: TypeConstructorDescription {
        case messageUserVote(userId: Int32, option: Buffer, date: Int32)
        case messageUserVoteInputOption(userId: Int32, date: Int32)
        case messageUserVoteMultiple(userId: Int32, options: [Buffer], date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageUserVote(let userId, let option, let date):
                    if boxed {
                        buffer.appendInt32(-1567730343)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .messageUserVoteInputOption(let userId, let date):
                    if boxed {
                        buffer.appendInt32(909603888)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .messageUserVoteMultiple(let userId, let options, let date):
                    if boxed {
                        buffer.appendInt32(244310238)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageUserVote(let userId, let option, let date):
                return ("messageUserVote", [("userId", userId), ("option", option), ("date", date)])
                case .messageUserVoteInputOption(let userId, let date):
                return ("messageUserVoteInputOption", [("userId", userId), ("date", date)])
                case .messageUserVoteMultiple(let userId, let options, let date):
                return ("messageUserVoteMultiple", [("userId", userId), ("options", options), ("date", date)])
    }
    }
    
        public static func parse_messageUserVote(_ reader: BufferReader) -> MessageUserVote? {
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
                return Api.MessageUserVote.messageUserVote(userId: _1!, option: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageUserVoteInputOption(_ reader: BufferReader) -> MessageUserVote? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageUserVote.messageUserVoteInputOption(userId: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageUserVoteMultiple(_ reader: BufferReader) -> MessageUserVote? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageUserVote.messageUserVoteMultiple(userId: _1!, options: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputDialogPeer: TypeConstructorDescription {
        case inputDialogPeer(peer: Api.InputPeer)
        case inputDialogPeerFolder(folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDialogPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-55902537)
                    }
                    peer.serialize(buffer, true)
                    break
                case .inputDialogPeerFolder(let folderId):
                    if boxed {
                        buffer.appendInt32(1684014375)
                    }
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDialogPeer(let peer):
                return ("inputDialogPeer", [("peer", peer)])
                case .inputDialogPeerFolder(let folderId):
                return ("inputDialogPeerFolder", [("folderId", folderId)])
    }
    }
    
        public static func parse_inputDialogPeer(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputDialogPeerFolder(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeerFolder(folderId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Error: TypeConstructorDescription {
        case error(code: Int32, text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .error(let code, let text):
                    if boxed {
                        buffer.appendInt32(-994444869)
                    }
                    serializeInt32(code, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .error(let code, let text):
                return ("error", [("code", code), ("text", text)])
    }
    }
    
        public static func parse_error(_ reader: BufferReader) -> Error? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Error.error(code: _1!, text: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum KeyboardButton: TypeConstructorDescription {
        case keyboardButton(text: String)
        case keyboardButtonUrl(text: String, url: String)
        case keyboardButtonCallback(text: String, data: Buffer)
        case keyboardButtonRequestPhone(text: String)
        case keyboardButtonRequestGeoLocation(text: String)
        case keyboardButtonSwitchInline(flags: Int32, text: String, query: String)
        case keyboardButtonGame(text: String)
        case keyboardButtonBuy(text: String)
        case keyboardButtonUrlAuth(flags: Int32, text: String, fwdText: String?, url: String, buttonId: Int32)
        case inputKeyboardButtonUrlAuth(flags: Int32, text: String, fwdText: String?, url: String, bot: Api.InputUser)
        case keyboardButtonRequestPoll(flags: Int32, quiz: Api.Bool?, text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .keyboardButton(let text):
                    if boxed {
                        buffer.appendInt32(-1560655744)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonUrl(let text, let url):
                    if boxed {
                        buffer.appendInt32(629866245)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonCallback(let text, let data):
                    if boxed {
                        buffer.appendInt32(1748655686)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonRequestPhone(let text):
                    if boxed {
                        buffer.appendInt32(-1318425559)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonRequestGeoLocation(let text):
                    if boxed {
                        buffer.appendInt32(-59151553)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonSwitchInline(let flags, let text, let query):
                    if boxed {
                        buffer.appendInt32(90744648)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonGame(let text):
                    if boxed {
                        buffer.appendInt32(1358175439)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonBuy(let text):
                    if boxed {
                        buffer.appendInt32(-1344716869)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let buttonId):
                    if boxed {
                        buffer.appendInt32(280464681)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(fwdText!, buffer: buffer, boxed: false)}
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    break
                case .inputKeyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let bot):
                    if boxed {
                        buffer.appendInt32(-802258988)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(fwdText!, buffer: buffer, boxed: false)}
                    serializeString(url, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    break
                case .keyboardButtonRequestPoll(let flags, let quiz, let text):
                    if boxed {
                        buffer.appendInt32(-1144565411)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {quiz!.serialize(buffer, true)}
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .keyboardButton(let text):
                return ("keyboardButton", [("text", text)])
                case .keyboardButtonUrl(let text, let url):
                return ("keyboardButtonUrl", [("text", text), ("url", url)])
                case .keyboardButtonCallback(let text, let data):
                return ("keyboardButtonCallback", [("text", text), ("data", data)])
                case .keyboardButtonRequestPhone(let text):
                return ("keyboardButtonRequestPhone", [("text", text)])
                case .keyboardButtonRequestGeoLocation(let text):
                return ("keyboardButtonRequestGeoLocation", [("text", text)])
                case .keyboardButtonSwitchInline(let flags, let text, let query):
                return ("keyboardButtonSwitchInline", [("flags", flags), ("text", text), ("query", query)])
                case .keyboardButtonGame(let text):
                return ("keyboardButtonGame", [("text", text)])
                case .keyboardButtonBuy(let text):
                return ("keyboardButtonBuy", [("text", text)])
                case .keyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let buttonId):
                return ("keyboardButtonUrlAuth", [("flags", flags), ("text", text), ("fwdText", fwdText), ("url", url), ("buttonId", buttonId)])
                case .inputKeyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let bot):
                return ("inputKeyboardButtonUrlAuth", [("flags", flags), ("text", text), ("fwdText", fwdText), ("url", url), ("bot", bot)])
                case .keyboardButtonRequestPoll(let flags, let quiz, let text):
                return ("keyboardButtonRequestPoll", [("flags", flags), ("quiz", quiz), ("text", text)])
    }
    }
    
        public static func parse_keyboardButton(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButton(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUrl(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonUrl(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonCallback(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonCallback(text: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPhone(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonRequestPhone(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestGeoLocation(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonRequestGeoLocation(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonSwitchInline(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonSwitchInline(flags: _1!, text: _2!, query: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonGame(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonGame(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonBuy(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonBuy(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.keyboardButtonUrlAuth(flags: _1!, text: _2!, fwdText: _3, url: _4!, buttonId: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputKeyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.InputUser?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.inputKeyboardButtonUrlAuth(flags: _1!, text: _2!, fwdText: _3, url: _4!, bot: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPoll(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonRequestPoll(flags: _1!, quiz: _2, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ContactStatus: TypeConstructorDescription {
        case contactStatus(userId: Int32, status: Api.UserStatus)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contactStatus(let userId, let status):
                    if boxed {
                        buffer.appendInt32(-748155807)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    status.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contactStatus(let userId, let status):
                return ("contactStatus", [("userId", userId), ("status", status)])
    }
    }
    
        public static func parse_contactStatus(_ reader: BufferReader) -> ContactStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.UserStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.UserStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ContactStatus.contactStatus(userId: _1!, status: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecureFile: TypeConstructorDescription {
        case secureFileEmpty
        case secureFile(id: Int64, accessHash: Int64, size: Int32, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureFileEmpty:
                    if boxed {
                        buffer.appendInt32(1679398724)
                    }
                    
                    break
                case .secureFile(let id, let accessHash, let size, let dcId, let date, let fileHash, let secret):
                    if boxed {
                        buffer.appendInt32(-534283678)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureFileEmpty:
                return ("secureFileEmpty", [])
                case .secureFile(let id, let accessHash, let size, let dcId, let date, let fileHash, let secret):
                return ("secureFile", [("id", id), ("accessHash", accessHash), ("size", size), ("dcId", dcId), ("date", date), ("fileHash", fileHash), ("secret", secret)])
    }
    }
    
        public static func parse_secureFileEmpty(_ reader: BufferReader) -> SecureFile? {
            return Api.SecureFile.secureFileEmpty
        }
        public static func parse_secureFile(_ reader: BufferReader) -> SecureFile? {
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
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Buffer?
            _7 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.SecureFile.secureFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, date: _5!, fileHash: _6!, secret: _7!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PhotoSize: TypeConstructorDescription {
        case photoSizeEmpty(type: String)
        case photoSize(type: String, location: Api.FileLocation, w: Int32, h: Int32, size: Int32)
        case photoCachedSize(type: String, location: Api.FileLocation, w: Int32, h: Int32, bytes: Buffer)
        case photoStrippedSize(type: String, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photoSizeEmpty(let type):
                    if boxed {
                        buffer.appendInt32(236446268)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    break
                case .photoSize(let type, let location, let w, let h, let size):
                    if boxed {
                        buffer.appendInt32(2009052699)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    break
                case .photoCachedSize(let type, let location, let w, let h, let bytes):
                    if boxed {
                        buffer.appendInt32(-374917894)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
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
                case .photoSizeEmpty(let type):
                return ("photoSizeEmpty", [("type", type)])
                case .photoSize(let type, let location, let w, let h, let size):
                return ("photoSize", [("type", type), ("location", location), ("w", w), ("h", h), ("size", size)])
                case .photoCachedSize(let type, let location, let w, let h, let bytes):
                return ("photoCachedSize", [("type", type), ("location", location), ("w", w), ("h", h), ("bytes", bytes)])
                case .photoStrippedSize(let type, let bytes):
                return ("photoStrippedSize", [("type", type), ("bytes", bytes)])
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
        public static func parse_photoSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.FileLocation?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.FileLocation
            }
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
                return Api.PhotoSize.photoSize(type: _1!, location: _2!, w: _3!, h: _4!, size: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoCachedSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.FileLocation?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.FileLocation
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PhotoSize.photoCachedSize(type: _1!, location: _2!, w: _3!, h: _4!, bytes: _5!)
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
    public enum InlineBotSwitchPM: TypeConstructorDescription {
        case inlineBotSwitchPM(text: String, startParam: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineBotSwitchPM(let text, let startParam):
                    if boxed {
                        buffer.appendInt32(1008755359)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineBotSwitchPM(let text, let startParam):
                return ("inlineBotSwitchPM", [("text", text), ("startParam", startParam)])
    }
    }
    
        public static func parse_inlineBotSwitchPM(_ reader: BufferReader) -> InlineBotSwitchPM? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineBotSwitchPM.inlineBotSwitchPM(text: _1!, startParam: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputTheme: TypeConstructorDescription {
        case inputTheme(id: Int64, accessHash: Int64)
        case inputThemeSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputTheme(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1012306921)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputThemeSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-175567375)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputTheme(let id, let accessHash):
                return ("inputTheme", [("id", id), ("accessHash", accessHash)])
                case .inputThemeSlug(let slug):
                return ("inputThemeSlug", [("slug", slug)])
    }
    }
    
        public static func parse_inputTheme(_ reader: BufferReader) -> InputTheme? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputTheme.inputTheme(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputThemeSlug(_ reader: BufferReader) -> InputTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputTheme.inputThemeSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FileLocation: TypeConstructorDescription {
        case fileLocationToBeDeprecated(volumeId: Int64, localId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileLocationToBeDeprecated(let volumeId, let localId):
                    if boxed {
                        buffer.appendInt32(-1132476723)
                    }
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileLocationToBeDeprecated(let volumeId, let localId):
                return ("fileLocationToBeDeprecated", [("volumeId", volumeId), ("localId", localId)])
    }
    }
    
        public static func parse_fileLocationToBeDeprecated(_ reader: BufferReader) -> FileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.FileLocation.fileLocationToBeDeprecated(volumeId: _1!, localId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Poll: TypeConstructorDescription {
        case poll(id: Int64, flags: Int32, question: String, answers: [Api.PollAnswer])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .poll(let id, let flags, let question, let answers):
                    if boxed {
                        buffer.appendInt32(-716006138)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(question, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(answers.count))
                    for item in answers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .poll(let id, let flags, let question, let answers):
                return ("poll", [("id", id), ("flags", flags), ("question", question), ("answers", answers)])
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Poll.poll(id: _1!, flags: _2!, question: _3!, answers: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputNotifyPeer: TypeConstructorDescription {
        case inputNotifyUsers
        case inputNotifyChats
        case inputNotifyBroadcasts
        case inputNotifyPeer(peer: Api.InputPeer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputNotifyUsers:
                    if boxed {
                        buffer.appendInt32(423314455)
                    }
                    
                    break
                case .inputNotifyChats:
                    if boxed {
                        buffer.appendInt32(1251338318)
                    }
                    
                    break
                case .inputNotifyBroadcasts:
                    if boxed {
                        buffer.appendInt32(-1311015810)
                    }
                    
                    break
                case .inputNotifyPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-1195615476)
                    }
                    peer.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputNotifyUsers:
                return ("inputNotifyUsers", [])
                case .inputNotifyChats:
                return ("inputNotifyChats", [])
                case .inputNotifyBroadcasts:
                return ("inputNotifyBroadcasts", [])
                case .inputNotifyPeer(let peer):
                return ("inputNotifyPeer", [("peer", peer)])
    }
    }
    
        public static func parse_inputNotifyUsers(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyUsers
        }
        public static func parse_inputNotifyChats(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyChats
        }
        public static func parse_inputNotifyBroadcasts(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyBroadcasts
        }
        public static func parse_inputNotifyPeer(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputNotifyPeer.inputNotifyPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum EncryptedMessage: TypeConstructorDescription {
        case encryptedMessage(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer, file: Api.EncryptedFile)
        case encryptedMessageService(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedMessage(let randomId, let chatId, let date, let bytes, let file):
                    if boxed {
                        buffer.appendInt32(-317144808)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    break
                case .encryptedMessageService(let randomId, let chatId, let date, let bytes):
                    if boxed {
                        buffer.appendInt32(594758406)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedMessage(let randomId, let chatId, let date, let bytes, let file):
                return ("encryptedMessage", [("randomId", randomId), ("chatId", chatId), ("date", date), ("bytes", bytes), ("file", file)])
                case .encryptedMessageService(let randomId, let chatId, let date, let bytes):
                return ("encryptedMessageService", [("randomId", randomId), ("chatId", chatId), ("date", date), ("bytes", bytes)])
    }
    }
    
        public static func parse_encryptedMessage(_ reader: BufferReader) -> EncryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.EncryptedFile?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.EncryptedFile
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedMessage.encryptedMessage(randomId: _1!, chatId: _2!, date: _3!, bytes: _4!, file: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedMessageService(_ reader: BufferReader) -> EncryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
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
                return Api.EncryptedMessage.encryptedMessageService(randomId: _1!, chatId: _2!, date: _3!, bytes: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelParticipantsFilter: TypeConstructorDescription {
        case channelParticipantsRecent
        case channelParticipantsAdmins
        case channelParticipantsBots
        case channelParticipantsBanned(q: String)
        case channelParticipantsSearch(q: String)
        case channelParticipantsKicked(q: String)
        case channelParticipantsContacts(q: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipantsRecent:
                    if boxed {
                        buffer.appendInt32(-566281095)
                    }
                    
                    break
                case .channelParticipantsAdmins:
                    if boxed {
                        buffer.appendInt32(-1268741783)
                    }
                    
                    break
                case .channelParticipantsBots:
                    if boxed {
                        buffer.appendInt32(-1328445861)
                    }
                    
                    break
                case .channelParticipantsBanned(let q):
                    if boxed {
                        buffer.appendInt32(338142689)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .channelParticipantsSearch(let q):
                    if boxed {
                        buffer.appendInt32(106343499)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .channelParticipantsKicked(let q):
                    if boxed {
                        buffer.appendInt32(-1548400251)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .channelParticipantsContacts(let q):
                    if boxed {
                        buffer.appendInt32(-1150621555)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelParticipantsRecent:
                return ("channelParticipantsRecent", [])
                case .channelParticipantsAdmins:
                return ("channelParticipantsAdmins", [])
                case .channelParticipantsBots:
                return ("channelParticipantsBots", [])
                case .channelParticipantsBanned(let q):
                return ("channelParticipantsBanned", [("q", q)])
                case .channelParticipantsSearch(let q):
                return ("channelParticipantsSearch", [("q", q)])
                case .channelParticipantsKicked(let q):
                return ("channelParticipantsKicked", [("q", q)])
                case .channelParticipantsContacts(let q):
                return ("channelParticipantsContacts", [("q", q)])
    }
    }
    
        public static func parse_channelParticipantsRecent(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            return Api.ChannelParticipantsFilter.channelParticipantsRecent
        }
        public static func parse_channelParticipantsAdmins(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            return Api.ChannelParticipantsFilter.channelParticipantsAdmins
        }
        public static func parse_channelParticipantsBots(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            return Api.ChannelParticipantsFilter.channelParticipantsBots
        }
        public static func parse_channelParticipantsBanned(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsBanned(q: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsSearch(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsSearch(q: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsKicked(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsKicked(q: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsContacts(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsContacts(q: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WebPage: TypeConstructorDescription {
        case webPageEmpty(id: Int64)
        case webPagePending(id: Int64, date: Int32)
        case webPageNotModified
        case webPage(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webPageEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-350980120)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .webPagePending(let id, let date):
                    if boxed {
                        buffer.appendInt32(-981018084)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .webPageNotModified:
                    if boxed {
                        buffer.appendInt32(-2054908813)
                    }
                    
                    break
                case .webPage(let flags, let id, let url, let displayUrl, let hash, let type, let siteName, let title, let description, let photo, let embedUrl, let embedType, let embedWidth, let embedHeight, let duration, let author, let document, let cachedPage, let attributes):
                    if boxed {
                        buffer.appendInt32(-392411726)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(displayUrl, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(type!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(siteName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(embedUrl!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(embedType!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(embedWidth!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(embedHeight!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(author!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 10) != 0 {cachedPage!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 12) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes!.count))
                    for item in attributes! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webPageEmpty(let id):
                return ("webPageEmpty", [("id", id)])
                case .webPagePending(let id, let date):
                return ("webPagePending", [("id", id), ("date", date)])
                case .webPageNotModified:
                return ("webPageNotModified", [])
                case .webPage(let flags, let id, let url, let displayUrl, let hash, let type, let siteName, let title, let description, let photo, let embedUrl, let embedType, let embedWidth, let embedHeight, let duration, let author, let document, let cachedPage, let attributes):
                return ("webPage", [("flags", flags), ("id", id), ("url", url), ("displayUrl", displayUrl), ("hash", hash), ("type", type), ("siteName", siteName), ("title", title), ("description", description), ("photo", photo), ("embedUrl", embedUrl), ("embedType", embedType), ("embedWidth", embedWidth), ("embedHeight", embedHeight), ("duration", duration), ("author", author), ("document", document), ("cachedPage", cachedPage), ("attributes", attributes)])
    }
    }
    
        public static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.WebPage.webPageEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.WebPage.webPagePending(id: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            return Api.WebPage.webPageNotModified
        }
        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
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
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            var _8: String?
            if Int(_1!) & Int(1 << 2) != 0 {_8 = parseString(reader) }
            var _9: String?
            if Int(_1!) & Int(1 << 3) != 0 {_9 = parseString(reader) }
            var _10: Api.Photo?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _11: String?
            if Int(_1!) & Int(1 << 5) != 0 {_11 = parseString(reader) }
            var _12: String?
            if Int(_1!) & Int(1 << 5) != 0 {_12 = parseString(reader) }
            var _13: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_14 = reader.readInt32() }
            var _15: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_15 = reader.readInt32() }
            var _16: String?
            if Int(_1!) & Int(1 << 8) != 0 {_16 = parseString(reader) }
            var _17: Api.Document?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _18: Api.Page?
            if Int(_1!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.Page
            } }
            var _19: [Api.WebPageAttribute]?
            if Int(_1!) & Int(1 << 12) != 0 {if let _ = reader.readInt32() {
                _19 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebPageAttribute.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 4) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 5) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 6) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 7) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 9) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 10) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 12) == 0) || _19 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 {
                return Api.WebPage.webPage(flags: _1!, id: _2!, url: _3!, displayUrl: _4!, hash: _5!, type: _6, siteName: _7, title: _8, description: _9, photo: _10, embedUrl: _11, embedType: _12, embedWidth: _13, embedHeight: _14, duration: _15, author: _16, document: _17, cachedPage: _18, attributes: _19)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputBotInlineMessage: TypeConstructorDescription {
        case inputBotInlineMessageText(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaGeo(flags: Int32, geoPoint: Api.InputGeoPoint, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageGame(flags: Int32, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaVenue(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotInlineMessageText(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1036876423)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-190472735)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageGame(let flags, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1262639204)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(864077702)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaVenue(let flags, let geoPoint, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1098628881)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1494368259)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineMessageText(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageText", [("flags", flags), ("message", message), ("entities", entities), ("replyMarkup", replyMarkup)])
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let replyMarkup):
                return ("inputBotInlineMessageMediaGeo", [("flags", flags), ("geoPoint", geoPoint), ("replyMarkup", replyMarkup)])
                case .inputBotInlineMessageGame(let flags, let replyMarkup):
                return ("inputBotInlineMessageGame", [("flags", flags), ("replyMarkup", replyMarkup)])
                case .inputBotInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageMediaAuto", [("flags", flags), ("message", message), ("entities", entities), ("replyMarkup", replyMarkup)])
                case .inputBotInlineMessageMediaVenue(let flags, let geoPoint, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                return ("inputBotInlineMessageMediaVenue", [("flags", flags), ("geoPoint", geoPoint), ("title", title), ("address", address), ("provider", provider), ("venueId", venueId), ("venueType", venueType), ("replyMarkup", replyMarkup)])
                case .inputBotInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                return ("inputBotInlineMessageMediaContact", [("flags", flags), ("phoneNumber", phoneNumber), ("firstName", firstName), ("lastName", lastName), ("vcard", vcard), ("replyMarkup", replyMarkup)])
    }
    }
    
        public static func parse_inputBotInlineMessageText(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessage.inputBotInlineMessageText(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaGeo(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaGeo(flags: _1!, geoPoint: _2!, replyMarkup: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageGame(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.InputBotInlineMessage.inputBotInlineMessageGame(flags: _1!, replyMarkup: _2)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaAuto(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaAuto(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaVenue(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
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
            var _8: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaVenue(flags: _1!, geoPoint: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!, replyMarkup: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaContact(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaContact(flags: _1!, phoneNumber: _2!, firstName: _3!, lastName: _4!, vcard: _5!, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
    
    }
    public enum KeyboardButtonRow: TypeConstructorDescription {
        case keyboardButtonRow(buttons: [Api.KeyboardButton])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .keyboardButtonRow(let buttons):
                    if boxed {
                        buffer.appendInt32(2002815875)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(buttons.count))
                    for item in buttons {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .keyboardButtonRow(let buttons):
                return ("keyboardButtonRow", [("buttons", buttons)])
    }
    }
    
        public static func parse_keyboardButtonRow(_ reader: BufferReader) -> KeyboardButtonRow? {
            var _1: [Api.KeyboardButton]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButton.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButtonRow.keyboardButtonRow(buttons: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum StickerSet: TypeConstructorDescription {
        case stickerSet(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumb: Api.PhotoSize?, thumbDcId: Int32?, count: Int32, hash: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSet(let flags, let installedDate, let id, let accessHash, let title, let shortName, let thumb, let thumbDcId, let count, let hash):
                    if boxed {
                        buffer.appendInt32(-290164953)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(installedDate!, buffer: buffer, boxed: false)}
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {thumb!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(thumbDcId!, buffer: buffer, boxed: false)}
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSet(let flags, let installedDate, let id, let accessHash, let title, let shortName, let thumb, let thumbDcId, let count, let hash):
                return ("stickerSet", [("flags", flags), ("installedDate", installedDate), ("id", id), ("accessHash", accessHash), ("title", title), ("shortName", shortName), ("thumb", thumb), ("thumbDcId", thumbDcId), ("count", count), ("hash", hash)])
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
            var _7: Api.PhotoSize?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PhotoSize
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.StickerSet.stickerSet(flags: _1!, installedDate: _2, id: _3!, accessHash: _4!, title: _5!, shortName: _6!, thumb: _7, thumbDcId: _8, count: _9!, hash: _10!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecureSecretSettings: TypeConstructorDescription {
        case secureSecretSettings(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureSecretSettings(let secureAlgo, let secureSecret, let secureSecretId):
                    if boxed {
                        buffer.appendInt32(354925740)
                    }
                    secureAlgo.serialize(buffer, true)
                    serializeBytes(secureSecret, buffer: buffer, boxed: false)
                    serializeInt64(secureSecretId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureSecretSettings(let secureAlgo, let secureSecret, let secureSecretId):
                return ("secureSecretSettings", [("secureAlgo", secureAlgo), ("secureSecret", secureSecret), ("secureSecretId", secureSecretId)])
    }
    }
    
        public static func parse_secureSecretSettings(_ reader: BufferReader) -> SecureSecretSettings? {
            var _1: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureSecretSettings.secureSecretSettings(secureAlgo: _1!, secureSecret: _2!, secureSecretId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputContact: TypeConstructorDescription {
        case inputPhoneContact(clientId: Int64, phone: String, firstName: String, lastName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoneContact(let clientId, let phone, let firstName, let lastName):
                    if boxed {
                        buffer.appendInt32(-208488460)
                    }
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoneContact(let clientId, let phone, let firstName, let lastName):
                return ("inputPhoneContact", [("clientId", clientId), ("phone", phone), ("firstName", firstName), ("lastName", lastName)])
    }
    }
    
        public static func parse_inputPhoneContact(_ reader: BufferReader) -> InputContact? {
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
                return Api.InputContact.inputPhoneContact(clientId: _1!, phone: _2!, firstName: _3!, lastName: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum TopPeerCategory: TypeConstructorDescription {
        case topPeerCategoryBotsPM
        case topPeerCategoryBotsInline
        case topPeerCategoryCorrespondents
        case topPeerCategoryGroups
        case topPeerCategoryChannels
        case topPeerCategoryPhoneCalls
        case topPeerCategoryForwardUsers
        case topPeerCategoryForwardChats
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeerCategoryBotsPM:
                    if boxed {
                        buffer.appendInt32(-1419371685)
                    }
                    
                    break
                case .topPeerCategoryBotsInline:
                    if boxed {
                        buffer.appendInt32(344356834)
                    }
                    
                    break
                case .topPeerCategoryCorrespondents:
                    if boxed {
                        buffer.appendInt32(104314861)
                    }
                    
                    break
                case .topPeerCategoryGroups:
                    if boxed {
                        buffer.appendInt32(-1122524854)
                    }
                    
                    break
                case .topPeerCategoryChannels:
                    if boxed {
                        buffer.appendInt32(371037736)
                    }
                    
                    break
                case .topPeerCategoryPhoneCalls:
                    if boxed {
                        buffer.appendInt32(511092620)
                    }
                    
                    break
                case .topPeerCategoryForwardUsers:
                    if boxed {
                        buffer.appendInt32(-1472172887)
                    }
                    
                    break
                case .topPeerCategoryForwardChats:
                    if boxed {
                        buffer.appendInt32(-68239120)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeerCategoryBotsPM:
                return ("topPeerCategoryBotsPM", [])
                case .topPeerCategoryBotsInline:
                return ("topPeerCategoryBotsInline", [])
                case .topPeerCategoryCorrespondents:
                return ("topPeerCategoryCorrespondents", [])
                case .topPeerCategoryGroups:
                return ("topPeerCategoryGroups", [])
                case .topPeerCategoryChannels:
                return ("topPeerCategoryChannels", [])
                case .topPeerCategoryPhoneCalls:
                return ("topPeerCategoryPhoneCalls", [])
                case .topPeerCategoryForwardUsers:
                return ("topPeerCategoryForwardUsers", [])
                case .topPeerCategoryForwardChats:
                return ("topPeerCategoryForwardChats", [])
    }
    }
    
        public static func parse_topPeerCategoryBotsPM(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsPM
        }
        public static func parse_topPeerCategoryBotsInline(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsInline
        }
        public static func parse_topPeerCategoryCorrespondents(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryCorrespondents
        }
        public static func parse_topPeerCategoryGroups(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryGroups
        }
        public static func parse_topPeerCategoryChannels(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryChannels
        }
        public static func parse_topPeerCategoryPhoneCalls(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryPhoneCalls
        }
        public static func parse_topPeerCategoryForwardUsers(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardUsers
        }
        public static func parse_topPeerCategoryForwardChats(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardChats
        }
    
    }
    public enum ChannelMessagesFilter: TypeConstructorDescription {
        case channelMessagesFilterEmpty
        case channelMessagesFilter(flags: Int32, ranges: [Api.MessageRange])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelMessagesFilterEmpty:
                    if boxed {
                        buffer.appendInt32(-1798033689)
                    }
                    
                    break
                case .channelMessagesFilter(let flags, let ranges):
                    if boxed {
                        buffer.appendInt32(-847783593)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ranges.count))
                    for item in ranges {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelMessagesFilterEmpty:
                return ("channelMessagesFilterEmpty", [])
                case .channelMessagesFilter(let flags, let ranges):
                return ("channelMessagesFilter", [("flags", flags), ("ranges", ranges)])
    }
    }
    
        public static func parse_channelMessagesFilterEmpty(_ reader: BufferReader) -> ChannelMessagesFilter? {
            return Api.ChannelMessagesFilter.channelMessagesFilterEmpty
        }
        public static func parse_channelMessagesFilter(_ reader: BufferReader) -> ChannelMessagesFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.MessageRange]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageRange.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelMessagesFilter.channelMessagesFilter(flags: _1!, ranges: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputDocument: TypeConstructorDescription {
        case inputDocumentEmpty
        case inputDocument(id: Int64, accessHash: Int64, fileReference: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDocumentEmpty:
                    if boxed {
                        buffer.appendInt32(1928391342)
                    }
                    
                    break
                case .inputDocument(let id, let accessHash, let fileReference):
                    if boxed {
                        buffer.appendInt32(448771445)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDocumentEmpty:
                return ("inputDocumentEmpty", [])
                case .inputDocument(let id, let accessHash, let fileReference):
                return ("inputDocument", [("id", id), ("accessHash", accessHash), ("fileReference", fileReference)])
    }
    }
    
        public static func parse_inputDocumentEmpty(_ reader: BufferReader) -> InputDocument? {
            return Api.InputDocument.inputDocumentEmpty
        }
        public static func parse_inputDocument(_ reader: BufferReader) -> InputDocument? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputDocument.inputDocument(id: _1!, accessHash: _2!, fileReference: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PollAnswer: TypeConstructorDescription {
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
                return ("pollAnswer", [("text", text), ("option", option)])
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
    public enum SecureData: TypeConstructorDescription {
        case secureData(data: Buffer, dataHash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureData(let data, let dataHash, let secret):
                    if boxed {
                        buffer.appendInt32(-1964327229)
                    }
                    serializeBytes(data, buffer: buffer, boxed: false)
                    serializeBytes(dataHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureData(let data, let dataHash, let secret):
                return ("secureData", [("data", data), ("dataHash", dataHash), ("secret", secret)])
    }
    }
    
        public static func parse_secureData(_ reader: BufferReader) -> SecureData? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureData.secureData(data: _1!, dataHash: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputMedia: TypeConstructorDescription {
        case inputMediaEmpty
        case inputMediaGeoPoint(geoPoint: Api.InputGeoPoint)
        case inputMediaGifExternal(url: String, q: String)
        case inputMediaGame(id: Api.InputGame)
        case inputMediaVenue(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case inputMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, startParam: String)
        case inputMediaUploadedPhoto(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaUploadedDocument(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaPhoto(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?)
        case inputMediaDocument(flags: Int32, id: Api.InputDocument, ttlSeconds: Int32?)
        case inputMediaPhotoExternal(flags: Int32, url: String, ttlSeconds: Int32?)
        case inputMediaDocumentExternal(flags: Int32, url: String, ttlSeconds: Int32?)
        case inputMediaContact(phoneNumber: String, firstName: String, lastName: String, vcard: String)
        case inputMediaGeoLive(flags: Int32, geoPoint: Api.InputGeoPoint, period: Int32?)
        case inputMediaPoll(flags: Int32, poll: Api.Poll, correctAnswers: [Buffer]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMediaEmpty:
                    if boxed {
                        buffer.appendInt32(-1771768449)
                    }
                    
                    break
                case .inputMediaGeoPoint(let geoPoint):
                    if boxed {
                        buffer.appendInt32(-104578748)
                    }
                    geoPoint.serialize(buffer, true)
                    break
                case .inputMediaGifExternal(let url, let q):
                    if boxed {
                        buffer.appendInt32(1212395773)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .inputMediaGame(let id):
                    if boxed {
                        buffer.appendInt32(-750828557)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputMediaVenue(let geoPoint, let title, let address, let provider, let venueId, let venueType):
                    if boxed {
                        buffer.appendInt32(-1052959727)
                    }
                    geoPoint.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    break
                case .inputMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let startParam):
                    if boxed {
                        buffer.appendInt32(-186607933)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    providerData.serialize(buffer, true)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    break
                case .inputMediaUploadedPhoto(let flags, let file, let stickers, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(505969924)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers!.count))
                    for item in stickers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaUploadedDocument(let flags, let file, let thumb, let mimeType, let attributes, let stickers, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(1530447553)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {thumb!.serialize(buffer, true)}
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers!.count))
                    for item in stickers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaPhoto(let flags, let id, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-1279654347)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaDocument(let flags, let id, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(598418386)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaPhotoExternal(let flags, let url, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-440664550)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaDocumentExternal(let flags, let url, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-78455655)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaContact(let phoneNumber, let firstName, let lastName, let vcard):
                    if boxed {
                        buffer.appendInt32(-122978821)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    break
                case .inputMediaGeoLive(let flags, let geoPoint, let period):
                    if boxed {
                        buffer.appendInt32(-833715459)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(period!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaPoll(let flags, let poll, let correctAnswers):
                    if boxed {
                        buffer.appendInt32(-1410741723)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    poll.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(correctAnswers!.count))
                    for item in correctAnswers! {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMediaEmpty:
                return ("inputMediaEmpty", [])
                case .inputMediaGeoPoint(let geoPoint):
                return ("inputMediaGeoPoint", [("geoPoint", geoPoint)])
                case .inputMediaGifExternal(let url, let q):
                return ("inputMediaGifExternal", [("url", url), ("q", q)])
                case .inputMediaGame(let id):
                return ("inputMediaGame", [("id", id)])
                case .inputMediaVenue(let geoPoint, let title, let address, let provider, let venueId, let venueType):
                return ("inputMediaVenue", [("geoPoint", geoPoint), ("title", title), ("address", address), ("provider", provider), ("venueId", venueId), ("venueType", venueType)])
                case .inputMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let startParam):
                return ("inputMediaInvoice", [("flags", flags), ("title", title), ("description", description), ("photo", photo), ("invoice", invoice), ("payload", payload), ("provider", provider), ("providerData", providerData), ("startParam", startParam)])
                case .inputMediaUploadedPhoto(let flags, let file, let stickers, let ttlSeconds):
                return ("inputMediaUploadedPhoto", [("flags", flags), ("file", file), ("stickers", stickers), ("ttlSeconds", ttlSeconds)])
                case .inputMediaUploadedDocument(let flags, let file, let thumb, let mimeType, let attributes, let stickers, let ttlSeconds):
                return ("inputMediaUploadedDocument", [("flags", flags), ("file", file), ("thumb", thumb), ("mimeType", mimeType), ("attributes", attributes), ("stickers", stickers), ("ttlSeconds", ttlSeconds)])
                case .inputMediaPhoto(let flags, let id, let ttlSeconds):
                return ("inputMediaPhoto", [("flags", flags), ("id", id), ("ttlSeconds", ttlSeconds)])
                case .inputMediaDocument(let flags, let id, let ttlSeconds):
                return ("inputMediaDocument", [("flags", flags), ("id", id), ("ttlSeconds", ttlSeconds)])
                case .inputMediaPhotoExternal(let flags, let url, let ttlSeconds):
                return ("inputMediaPhotoExternal", [("flags", flags), ("url", url), ("ttlSeconds", ttlSeconds)])
                case .inputMediaDocumentExternal(let flags, let url, let ttlSeconds):
                return ("inputMediaDocumentExternal", [("flags", flags), ("url", url), ("ttlSeconds", ttlSeconds)])
                case .inputMediaContact(let phoneNumber, let firstName, let lastName, let vcard):
                return ("inputMediaContact", [("phoneNumber", phoneNumber), ("firstName", firstName), ("lastName", lastName), ("vcard", vcard)])
                case .inputMediaGeoLive(let flags, let geoPoint, let period):
                return ("inputMediaGeoLive", [("flags", flags), ("geoPoint", geoPoint), ("period", period)])
                case .inputMediaPoll(let flags, let poll, let correctAnswers):
                return ("inputMediaPoll", [("flags", flags), ("poll", poll), ("correctAnswers", correctAnswers)])
    }
    }
    
        public static func parse_inputMediaEmpty(_ reader: BufferReader) -> InputMedia? {
            return Api.InputMedia.inputMediaEmpty
        }
        public static func parse_inputMediaGeoPoint(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaGeoPoint(geoPoint: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGifExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMedia.inputMediaGifExternal(url: _1!, q: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGame(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGame?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGame
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaGame(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaVenue(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
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
                return Api.InputMedia.inputMediaVenue(geoPoint: _1!, title: _2!, address: _3!, provider: _4!, venueId: _5!, venueType: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaInvoice(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _5: Api.Invoice?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: String?
            _7 = parseString(reader)
            var _8: Api.DataJSON?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputMedia.inputMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7!, providerData: _8!, startParam: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaUploadedPhoto(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            var _3: [Api.InputDocument]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaUploadedPhoto(flags: _1!, file: _2!, stickers: _3, ttlSeconds: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaUploadedDocument(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            var _6: [Api.InputDocument]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
            } }
            var _7: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputMedia.inputMediaUploadedDocument(flags: _1!, file: _2!, thumb: _3, mimeType: _4!, attributes: _5!, stickers: _6, ttlSeconds: _7)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPhoto(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaPhoto(flags: _1!, id: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDocument(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaDocument(flags: _1!, id: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPhotoExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaPhotoExternal(flags: _1!, url: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDocumentExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaDocumentExternal(flags: _1!, url: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaContact(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
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
                return Api.InputMedia.inputMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, vcard: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGeoLive(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaGeoLive(flags: _1!, geoPoint: _2!, period: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPoll(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Poll?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Poll
            }
            var _3: [Buffer]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaPoll(flags: _1!, poll: _2!, correctAnswers: _3)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputPeer: TypeConstructorDescription {
        case inputPeerEmpty
        case inputPeerSelf
        case inputPeerChat(chatId: Int32)
        case inputPeerUser(userId: Int32, accessHash: Int64)
        case inputPeerChannel(channelId: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPeerEmpty:
                    if boxed {
                        buffer.appendInt32(2134579434)
                    }
                    
                    break
                case .inputPeerSelf:
                    if boxed {
                        buffer.appendInt32(2107670217)
                    }
                    
                    break
                case .inputPeerChat(let chatId):
                    if boxed {
                        buffer.appendInt32(396093539)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .inputPeerUser(let userId, let accessHash):
                    if boxed {
                        buffer.appendInt32(2072935910)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputPeerChannel(let channelId, let accessHash):
                    if boxed {
                        buffer.appendInt32(548253432)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPeerEmpty:
                return ("inputPeerEmpty", [])
                case .inputPeerSelf:
                return ("inputPeerSelf", [])
                case .inputPeerChat(let chatId):
                return ("inputPeerChat", [("chatId", chatId)])
                case .inputPeerUser(let userId, let accessHash):
                return ("inputPeerUser", [("userId", userId), ("accessHash", accessHash)])
                case .inputPeerChannel(let channelId, let accessHash):
                return ("inputPeerChannel", [("channelId", channelId), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputPeerEmpty(_ reader: BufferReader) -> InputPeer? {
            return Api.InputPeer.inputPeerEmpty
        }
        public static func parse_inputPeerSelf(_ reader: BufferReader) -> InputPeer? {
            return Api.InputPeer.inputPeerSelf
        }
        public static func parse_inputPeerChat(_ reader: BufferReader) -> InputPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPeer.inputPeerChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerUser(_ reader: BufferReader) -> InputPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPeer.inputPeerUser(userId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerChannel(_ reader: BufferReader) -> InputPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPeer.inputPeerChannel(channelId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Contact: TypeConstructorDescription {
        case contact(userId: Int32, mutual: Api.Bool)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contact(let userId, let mutual):
                    if boxed {
                        buffer.appendInt32(-116274796)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    mutual.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contact(let userId, let mutual):
                return ("contact", [("userId", userId), ("mutual", mutual)])
    }
    }
    
        public static func parse_contact(_ reader: BufferReader) -> Contact? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Contact.contact(userId: _1!, mutual: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FileHash: TypeConstructorDescription {
        case fileHash(offset: Int32, limit: Int32, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileHash(let offset, let limit, let hash):
                    if boxed {
                        buffer.appendInt32(1648543603)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileHash(let offset, let limit, let hash):
                return ("fileHash", [("offset", offset), ("limit", limit), ("hash", hash)])
    }
    }
    
        public static func parse_fileHash(_ reader: BufferReader) -> FileHash? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.FileHash.fileHash(offset: _1!, limit: _2!, hash: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BotInlineResult: TypeConstructorDescription {
        case botInlineMediaResult(flags: Int32, id: String, type: String, photo: Api.Photo?, document: Api.Document?, title: String?, description: String?, sendMessage: Api.BotInlineMessage)
        case botInlineResult(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.WebDocument?, content: Api.WebDocument?, sendMessage: Api.BotInlineMessage)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInlineMediaResult(let flags, let id, let type, let photo, let document, let title, let description, let sendMessage):
                    if boxed {
                        buffer.appendInt32(400266251)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    sendMessage.serialize(buffer, true)
                    break
                case .botInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                    if boxed {
                        buffer.appendInt32(295067450)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {thumb!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {content!.serialize(buffer, true)}
                    sendMessage.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInlineMediaResult(let flags, let id, let type, let photo, let document, let title, let description, let sendMessage):
                return ("botInlineMediaResult", [("flags", flags), ("id", id), ("type", type), ("photo", photo), ("document", document), ("title", title), ("description", description), ("sendMessage", sendMessage)])
                case .botInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                return ("botInlineResult", [("flags", flags), ("id", id), ("type", type), ("title", title), ("description", description), ("url", url), ("thumb", thumb), ("content", content), ("sendMessage", sendMessage)])
    }
    }
    
        public static func parse_botInlineMediaResult(_ reader: BufferReader) -> BotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _5: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = parseString(reader) }
            var _8: Api.BotInlineMessage?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.BotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.BotInlineResult.botInlineMediaResult(flags: _1!, id: _2!, type: _3!, photo: _4, document: _5, title: _6, description: _7, sendMessage: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineResult(_ reader: BufferReader) -> BotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: Api.WebDocument?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _9: Api.BotInlineMessage?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.BotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.BotInlineResult.botInlineResult(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, url: _6, thumb: _7, content: _8, sendMessage: _9!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputSingleMedia: TypeConstructorDescription {
        case inputSingleMedia(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSingleMedia(let flags, let media, let randomId, let message, let entities):
                    if boxed {
                        buffer.appendInt32(482797855)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSingleMedia(let flags, let media, let randomId, let message, let entities):
                return ("inputSingleMedia", [("flags", flags), ("media", media), ("randomId", randomId), ("message", message), ("entities", entities)])
    }
    }
    
        public static func parse_inputSingleMedia(_ reader: BufferReader) -> InputSingleMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputMedia?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputMedia
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSingleMedia.inputSingleMedia(flags: _1!, media: _2!, randomId: _3!, message: _4!, entities: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputPrivacyRule: TypeConstructorDescription {
        case inputPrivacyValueAllowContacts
        case inputPrivacyValueAllowAll
        case inputPrivacyValueAllowUsers(users: [Api.InputUser])
        case inputPrivacyValueDisallowContacts
        case inputPrivacyValueDisallowAll
        case inputPrivacyValueDisallowUsers(users: [Api.InputUser])
        case inputPrivacyValueAllowChatParticipants(chats: [Int32])
        case inputPrivacyValueDisallowChatParticipants(chats: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPrivacyValueAllowContacts:
                    if boxed {
                        buffer.appendInt32(218751099)
                    }
                    
                    break
                case .inputPrivacyValueAllowAll:
                    if boxed {
                        buffer.appendInt32(407582158)
                    }
                    
                    break
                case .inputPrivacyValueAllowUsers(let users):
                    if boxed {
                        buffer.appendInt32(320652927)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .inputPrivacyValueDisallowContacts:
                    if boxed {
                        buffer.appendInt32(195371015)
                    }
                    
                    break
                case .inputPrivacyValueDisallowAll:
                    if boxed {
                        buffer.appendInt32(-697604407)
                    }
                    
                    break
                case .inputPrivacyValueDisallowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-1877932953)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .inputPrivacyValueAllowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(1283572154)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .inputPrivacyValueDisallowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(-668769361)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPrivacyValueAllowContacts:
                return ("inputPrivacyValueAllowContacts", [])
                case .inputPrivacyValueAllowAll:
                return ("inputPrivacyValueAllowAll", [])
                case .inputPrivacyValueAllowUsers(let users):
                return ("inputPrivacyValueAllowUsers", [("users", users)])
                case .inputPrivacyValueDisallowContacts:
                return ("inputPrivacyValueDisallowContacts", [])
                case .inputPrivacyValueDisallowAll:
                return ("inputPrivacyValueDisallowAll", [])
                case .inputPrivacyValueDisallowUsers(let users):
                return ("inputPrivacyValueDisallowUsers", [("users", users)])
                case .inputPrivacyValueAllowChatParticipants(let chats):
                return ("inputPrivacyValueAllowChatParticipants", [("chats", chats)])
                case .inputPrivacyValueDisallowChatParticipants(let chats):
                return ("inputPrivacyValueDisallowChatParticipants", [("chats", chats)])
    }
    }
    
        public static func parse_inputPrivacyValueAllowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowContacts
        }
        public static func parse_inputPrivacyValueAllowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowAll
        }
        public static func parse_inputPrivacyValueAllowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowContacts
        }
        public static func parse_inputPrivacyValueDisallowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowAll
        }
        public static func parse_inputPrivacyValueDisallowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueAllowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelAdminLogEventAction: TypeConstructorDescription {
        case channelAdminLogEventActionChangeTitle(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeAbout(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsername(prevValue: String, newValue: String)
        case channelAdminLogEventActionToggleInvites(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSignatures(newValue: Api.Bool)
        case channelAdminLogEventActionUpdatePinned(message: Api.Message)
        case channelAdminLogEventActionEditMessage(prevMessage: Api.Message, newMessage: Api.Message)
        case channelAdminLogEventActionDeleteMessage(message: Api.Message)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantInvite(participant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleBan(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionChangeStickerSet(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet)
        case channelAdminLogEventActionTogglePreHistoryHidden(newValue: Api.Bool)
        case channelAdminLogEventActionDefaultBannedRights(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights)
        case channelAdminLogEventActionStopPoll(message: Api.Message)
        case channelAdminLogEventActionChangePhoto(prevPhoto: Api.Photo, newPhoto: Api.Photo)
        case channelAdminLogEventActionChangeLinkedChat(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionChangeLocation(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation)
        case channelAdminLogEventActionToggleSlowMode(prevValue: Int32, newValue: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEventActionChangeTitle(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-421545947)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeAbout(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1427671598)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeUsername(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1783299128)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionToggleInvites(let newValue):
                    if boxed {
                        buffer.appendInt32(460916654)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSignatures(let newValue):
                    if boxed {
                        buffer.appendInt32(648939889)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionUpdatePinned(let message):
                    if boxed {
                        buffer.appendInt32(-370660328)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionEditMessage(let prevMessage, let newMessage):
                    if boxed {
                        buffer.appendInt32(1889215493)
                    }
                    prevMessage.serialize(buffer, true)
                    newMessage.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDeleteMessage(let message):
                    if boxed {
                        buffer.appendInt32(1121994683)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantJoin:
                    if boxed {
                        buffer.appendInt32(405815507)
                    }
                    
                    break
                case .channelAdminLogEventActionParticipantLeave:
                    if boxed {
                        buffer.appendInt32(-124291086)
                    }
                    
                    break
                case .channelAdminLogEventActionParticipantInvite(let participant):
                    if boxed {
                        buffer.appendInt32(-484690728)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantToggleBan(let prevParticipant, let newParticipant):
                    if boxed {
                        buffer.appendInt32(-422036098)
                    }
                    prevParticipant.serialize(buffer, true)
                    newParticipant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantToggleAdmin(let prevParticipant, let newParticipant):
                    if boxed {
                        buffer.appendInt32(-714643696)
                    }
                    prevParticipant.serialize(buffer, true)
                    newParticipant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeStickerSet(let prevStickerset, let newStickerset):
                    if boxed {
                        buffer.appendInt32(-1312568665)
                    }
                    prevStickerset.serialize(buffer, true)
                    newStickerset.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionTogglePreHistoryHidden(let newValue):
                    if boxed {
                        buffer.appendInt32(1599903217)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDefaultBannedRights(let prevBannedRights, let newBannedRights):
                    if boxed {
                        buffer.appendInt32(771095562)
                    }
                    prevBannedRights.serialize(buffer, true)
                    newBannedRights.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionStopPoll(let message):
                    if boxed {
                        buffer.appendInt32(-1895328189)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangePhoto(let prevPhoto, let newPhoto):
                    if boxed {
                        buffer.appendInt32(1129042607)
                    }
                    prevPhoto.serialize(buffer, true)
                    newPhoto.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeLinkedChat(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-1569748965)
                    }
                    serializeInt32(prevValue, buffer: buffer, boxed: false)
                    serializeInt32(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeLocation(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(241923758)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSlowMode(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1401984889)
                    }
                    serializeInt32(prevValue, buffer: buffer, boxed: false)
                    serializeInt32(newValue, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEventActionChangeTitle(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeTitle", [("prevValue", prevValue), ("newValue", newValue)])
                case .channelAdminLogEventActionChangeAbout(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeAbout", [("prevValue", prevValue), ("newValue", newValue)])
                case .channelAdminLogEventActionChangeUsername(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeUsername", [("prevValue", prevValue), ("newValue", newValue)])
                case .channelAdminLogEventActionToggleInvites(let newValue):
                return ("channelAdminLogEventActionToggleInvites", [("newValue", newValue)])
                case .channelAdminLogEventActionToggleSignatures(let newValue):
                return ("channelAdminLogEventActionToggleSignatures", [("newValue", newValue)])
                case .channelAdminLogEventActionUpdatePinned(let message):
                return ("channelAdminLogEventActionUpdatePinned", [("message", message)])
                case .channelAdminLogEventActionEditMessage(let prevMessage, let newMessage):
                return ("channelAdminLogEventActionEditMessage", [("prevMessage", prevMessage), ("newMessage", newMessage)])
                case .channelAdminLogEventActionDeleteMessage(let message):
                return ("channelAdminLogEventActionDeleteMessage", [("message", message)])
                case .channelAdminLogEventActionParticipantJoin:
                return ("channelAdminLogEventActionParticipantJoin", [])
                case .channelAdminLogEventActionParticipantLeave:
                return ("channelAdminLogEventActionParticipantLeave", [])
                case .channelAdminLogEventActionParticipantInvite(let participant):
                return ("channelAdminLogEventActionParticipantInvite", [("participant", participant)])
                case .channelAdminLogEventActionParticipantToggleBan(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantToggleBan", [("prevParticipant", prevParticipant), ("newParticipant", newParticipant)])
                case .channelAdminLogEventActionParticipantToggleAdmin(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantToggleAdmin", [("prevParticipant", prevParticipant), ("newParticipant", newParticipant)])
                case .channelAdminLogEventActionChangeStickerSet(let prevStickerset, let newStickerset):
                return ("channelAdminLogEventActionChangeStickerSet", [("prevStickerset", prevStickerset), ("newStickerset", newStickerset)])
                case .channelAdminLogEventActionTogglePreHistoryHidden(let newValue):
                return ("channelAdminLogEventActionTogglePreHistoryHidden", [("newValue", newValue)])
                case .channelAdminLogEventActionDefaultBannedRights(let prevBannedRights, let newBannedRights):
                return ("channelAdminLogEventActionDefaultBannedRights", [("prevBannedRights", prevBannedRights), ("newBannedRights", newBannedRights)])
                case .channelAdminLogEventActionStopPoll(let message):
                return ("channelAdminLogEventActionStopPoll", [("message", message)])
                case .channelAdminLogEventActionChangePhoto(let prevPhoto, let newPhoto):
                return ("channelAdminLogEventActionChangePhoto", [("prevPhoto", prevPhoto), ("newPhoto", newPhoto)])
                case .channelAdminLogEventActionChangeLinkedChat(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeLinkedChat", [("prevValue", prevValue), ("newValue", newValue)])
                case .channelAdminLogEventActionChangeLocation(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeLocation", [("prevValue", prevValue), ("newValue", newValue)])
                case .channelAdminLogEventActionToggleSlowMode(let prevValue, let newValue):
                return ("channelAdminLogEventActionToggleSlowMode", [("prevValue", prevValue), ("newValue", newValue)])
    }
    }
    
        public static func parse_channelAdminLogEventActionChangeTitle(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeTitle(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeAbout(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeAbout(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeUsername(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeUsername(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleInvites(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleInvites(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleSignatures(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSignatures(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionUpdatePinned(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionUpdatePinned(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionEditMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Api.Message?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionEditMessage(prevMessage: _1!, newMessage: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDeleteMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDeleteMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantJoin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoin
        }
        public static func parse_channelAdminLogEventActionParticipantLeave(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantLeave
        }
        public static func parse_channelAdminLogEventActionParticipantInvite(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantInvite(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantToggleBan(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            var _2: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantToggleBan(prevParticipant: _1!, newParticipant: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantToggleAdmin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            var _2: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: _1!, newParticipant: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeStickerSet(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeStickerSet(prevStickerset: _1!, newStickerset: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionTogglePreHistoryHidden(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionTogglePreHistoryHidden(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDefaultBannedRights(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            var _2: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDefaultBannedRights(prevBannedRights: _1!, newBannedRights: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionStopPoll(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionStopPoll(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangePhoto(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: Api.Photo?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangePhoto(prevPhoto: _1!, newPhoto: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeLinkedChat(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeLinkedChat(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeLocation(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelLocation?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
            }
            var _2: Api.ChannelLocation?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeLocation(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleSlowMode(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSlowMode(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecurePlainData: TypeConstructorDescription {
        case securePlainPhone(phone: String)
        case securePlainEmail(email: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .securePlainPhone(let phone):
                    if boxed {
                        buffer.appendInt32(2103482845)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
                case .securePlainEmail(let email):
                    if boxed {
                        buffer.appendInt32(569137759)
                    }
                    serializeString(email, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .securePlainPhone(let phone):
                return ("securePlainPhone", [("phone", phone)])
                case .securePlainEmail(let email):
                return ("securePlainEmail", [("email", email)])
    }
    }
    
        public static func parse_securePlainPhone(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainPhone(phone: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_securePlainEmail(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainEmail(email: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PageTableCell: TypeConstructorDescription {
        case pageTableCell(flags: Int32, text: Api.RichText?, colspan: Int32?, rowspan: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageTableCell(let flags, let text, let colspan, let rowspan):
                    if boxed {
                        buffer.appendInt32(878078826)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {text!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(colspan!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(rowspan!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageTableCell(let flags, let text, let colspan, let rowspan):
                return ("pageTableCell", [("flags", flags), ("text", text), ("colspan", colspan), ("rowspan", rowspan)])
    }
    }
    
        public static func parse_pageTableCell(_ reader: BufferReader) -> PageTableCell? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.RichText?
            if Int(_1!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 7) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PageTableCell.pageTableCell(flags: _1!, text: _2, colspan: _3, rowspan: _4)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatBannedRights: TypeConstructorDescription {
        case chatBannedRights(flags: Int32, untilDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatBannedRights(let flags, let untilDate):
                    if boxed {
                        buffer.appendInt32(-1626209256)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatBannedRights(let flags, let untilDate):
                return ("chatBannedRights", [("flags", flags), ("untilDate", untilDate)])
    }
    }
    
        public static func parse_chatBannedRights(_ reader: BufferReader) -> ChatBannedRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChatBannedRights.chatBannedRights(flags: _1!, untilDate: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum LabeledPrice: TypeConstructorDescription {
        case labeledPrice(label: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .labeledPrice(let label, let amount):
                    if boxed {
                        buffer.appendInt32(-886477832)
                    }
                    serializeString(label, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .labeledPrice(let label, let amount):
                return ("labeledPrice", [("label", label), ("amount", amount)])
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
                return Api.LabeledPrice.labeledPrice(label: _1!, amount: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputSecureValue: TypeConstructorDescription {
        case inputSecureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSecureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData):
                    if boxed {
                        buffer.appendInt32(-618540889)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {data!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {frontSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {reverseSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {selfie!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(translation!.count))
                    for item in translation! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(files!.count))
                    for item in files! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {plainData!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSecureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData):
                return ("inputSecureValue", [("flags", flags), ("type", type), ("data", data), ("frontSide", frontSide), ("reverseSide", reverseSide), ("selfie", selfie), ("translation", translation), ("files", files), ("plainData", plainData)])
    }
    }
    
        public static func parse_inputSecureValue(_ reader: BufferReader) -> InputSecureValue? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _3: Api.SecureData?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureData
            } }
            var _4: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _5: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _6: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _7: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
            } }
            var _8: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
            } }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputSecureValue.inputSecureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ReportReason: TypeConstructorDescription {
        case inputReportReasonSpam
        case inputReportReasonViolence
        case inputReportReasonPornography
        case inputReportReasonOther(text: String)
        case inputReportReasonCopyright
        case inputReportReasonChildAbuse
        case inputReportReasonGeoIrrelevant
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .inputReportReasonPornography:
                    if boxed {
                        buffer.appendInt32(777640226)
                    }
                    
                    break
                case .inputReportReasonOther(let text):
                    if boxed {
                        buffer.appendInt32(-512463606)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .inputReportReasonCopyright:
                    if boxed {
                        buffer.appendInt32(-1685456582)
                    }
                    
                    break
                case .inputReportReasonChildAbuse:
                    if boxed {
                        buffer.appendInt32(-1376497949)
                    }
                    
                    break
                case .inputReportReasonGeoIrrelevant:
                    if boxed {
                        buffer.appendInt32(-606798099)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputReportReasonSpam:
                return ("inputReportReasonSpam", [])
                case .inputReportReasonViolence:
                return ("inputReportReasonViolence", [])
                case .inputReportReasonPornography:
                return ("inputReportReasonPornography", [])
                case .inputReportReasonOther(let text):
                return ("inputReportReasonOther", [("text", text)])
                case .inputReportReasonCopyright:
                return ("inputReportReasonCopyright", [])
                case .inputReportReasonChildAbuse:
                return ("inputReportReasonChildAbuse", [])
                case .inputReportReasonGeoIrrelevant:
                return ("inputReportReasonGeoIrrelevant", [])
    }
    }
    
        public static func parse_inputReportReasonSpam(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonSpam
        }
        public static func parse_inputReportReasonViolence(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonViolence
        }
        public static func parse_inputReportReasonPornography(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonPornography
        }
        public static func parse_inputReportReasonOther(_ reader: BufferReader) -> ReportReason? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReportReason.inputReportReasonOther(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputReportReasonCopyright(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonCopyright
        }
        public static func parse_inputReportReasonChildAbuse(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonChildAbuse
        }
        public static func parse_inputReportReasonGeoIrrelevant(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonGeoIrrelevant
        }
    
    }
    public enum InputEncryptedChat: TypeConstructorDescription {
        case inputEncryptedChat(chatId: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedChat(let chatId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-247351839)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedChat(let chatId, let accessHash):
                return ("inputEncryptedChat", [("chatId", chatId), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputEncryptedChat(_ reader: BufferReader) -> InputEncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputEncryptedChat.inputEncryptedChat(chatId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PageTableRow: TypeConstructorDescription {
        case pageTableRow(cells: [Api.PageTableCell])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageTableRow(let cells):
                    if boxed {
                        buffer.appendInt32(-524237339)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(cells.count))
                    for item in cells {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageTableRow(let cells):
                return ("pageTableRow", [("cells", cells)])
    }
    }
    
        public static func parse_pageTableRow(_ reader: BufferReader) -> PageTableRow? {
            var _1: [Api.PageTableCell]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageTableCell.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageTableRow.pageTableRow(cells: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum DraftMessage: TypeConstructorDescription {
        case draftMessage(flags: Int32, replyToMsgId: Int32?, message: String, entities: [Api.MessageEntity]?, date: Int32)
        case draftMessageEmpty(flags: Int32, date: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .draftMessage(let flags, let replyToMsgId, let message, let entities, let date):
                    if boxed {
                        buffer.appendInt32(-40996577)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .draftMessageEmpty(let flags, let date):
                    if boxed {
                        buffer.appendInt32(453805082)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(date!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .draftMessage(let flags, let replyToMsgId, let message, let entities, let date):
                return ("draftMessage", [("flags", flags), ("replyToMsgId", replyToMsgId), ("message", message), ("entities", entities), ("date", date)])
                case .draftMessageEmpty(let flags, let date):
                return ("draftMessageEmpty", [("flags", flags), ("date", date)])
    }
    }
    
        public static func parse_draftMessage(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DraftMessage.draftMessage(flags: _1!, replyToMsgId: _2, message: _3!, entities: _4, date: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_draftMessageEmpty(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.DraftMessage.draftMessageEmpty(flags: _1!, date: _2)
            }
            else {
                return nil
            }
        }
    
    }
    public enum EncryptedFile: TypeConstructorDescription {
        case encryptedFileEmpty
        case encryptedFile(id: Int64, accessHash: Int64, size: Int32, dcId: Int32, keyFingerprint: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedFileEmpty:
                    if boxed {
                        buffer.appendInt32(-1038136962)
                    }
                    
                    break
                case .encryptedFile(let id, let accessHash, let size, let dcId, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1248893260)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedFileEmpty:
                return ("encryptedFileEmpty", [])
                case .encryptedFile(let id, let accessHash, let size, let dcId, let keyFingerprint):
                return ("encryptedFile", [("id", id), ("accessHash", accessHash), ("size", size), ("dcId", dcId), ("keyFingerprint", keyFingerprint)])
    }
    }
    
        public static func parse_encryptedFileEmpty(_ reader: BufferReader) -> EncryptedFile? {
            return Api.EncryptedFile.encryptedFileEmpty
        }
        public static func parse_encryptedFile(_ reader: BufferReader) -> EncryptedFile? {
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
                return Api.EncryptedFile.encryptedFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, keyFingerprint: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum CodeSettings: TypeConstructorDescription {
        case codeSettings(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .codeSettings(let flags):
                    if boxed {
                        buffer.appendInt32(-557924733)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .codeSettings(let flags):
                return ("codeSettings", [("flags", flags)])
    }
    }
    
        public static func parse_codeSettings(_ reader: BufferReader) -> CodeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.CodeSettings.codeSettings(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecureValueError: TypeConstructorDescription {
        case secureValueErrorData(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String)
        case secureValueErrorFrontSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorReverseSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorSelfie(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
        case secureValueError(type: Api.SecureValueType, hash: Buffer, text: String)
        case secureValueErrorTranslationFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueErrorData(let type, let dataHash, let field, let text):
                    if boxed {
                        buffer.appendInt32(-391902247)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(dataHash, buffer: buffer, boxed: false)
                    serializeString(field, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFrontSide(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(12467706)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorReverseSide(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-2037765467)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorSelfie(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-449327402)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFile(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(2054162547)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFiles(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(1717706985)
                    }
                    type.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHash.count))
                    for item in fileHash {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueError(let type, let hash, let text):
                    if boxed {
                        buffer.appendInt32(-2036501105)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorTranslationFile(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-1592506512)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorTranslationFiles(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(878931416)
                    }
                    type.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHash.count))
                    for item in fileHash {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueErrorData(let type, let dataHash, let field, let text):
                return ("secureValueErrorData", [("type", type), ("dataHash", dataHash), ("field", field), ("text", text)])
                case .secureValueErrorFrontSide(let type, let fileHash, let text):
                return ("secureValueErrorFrontSide", [("type", type), ("fileHash", fileHash), ("text", text)])
                case .secureValueErrorReverseSide(let type, let fileHash, let text):
                return ("secureValueErrorReverseSide", [("type", type), ("fileHash", fileHash), ("text", text)])
                case .secureValueErrorSelfie(let type, let fileHash, let text):
                return ("secureValueErrorSelfie", [("type", type), ("fileHash", fileHash), ("text", text)])
                case .secureValueErrorFile(let type, let fileHash, let text):
                return ("secureValueErrorFile", [("type", type), ("fileHash", fileHash), ("text", text)])
                case .secureValueErrorFiles(let type, let fileHash, let text):
                return ("secureValueErrorFiles", [("type", type), ("fileHash", fileHash), ("text", text)])
                case .secureValueError(let type, let hash, let text):
                return ("secureValueError", [("type", type), ("hash", hash), ("text", text)])
                case .secureValueErrorTranslationFile(let type, let fileHash, let text):
                return ("secureValueErrorTranslationFile", [("type", type), ("fileHash", fileHash), ("text", text)])
                case .secureValueErrorTranslationFiles(let type, let fileHash, let text):
                return ("secureValueErrorTranslationFiles", [("type", type), ("fileHash", fileHash), ("text", text)])
    }
    }
    
        public static func parse_secureValueErrorData(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SecureValueError.secureValueErrorData(type: _1!, dataHash: _2!, field: _3!, text: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFrontSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFrontSide(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorReverseSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorReverseSide(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorSelfie(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorSelfie(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFile(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFiles(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueError(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueError(type: _1!, hash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFile(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFiles(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum NotifyPeer: TypeConstructorDescription {
        case notifyPeer(peer: Api.Peer)
        case notifyUsers
        case notifyChats
        case notifyBroadcasts
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .notifyPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-1613493288)
                    }
                    peer.serialize(buffer, true)
                    break
                case .notifyUsers:
                    if boxed {
                        buffer.appendInt32(-1261946036)
                    }
                    
                    break
                case .notifyChats:
                    if boxed {
                        buffer.appendInt32(-1073230141)
                    }
                    
                    break
                case .notifyBroadcasts:
                    if boxed {
                        buffer.appendInt32(-703403793)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .notifyPeer(let peer):
                return ("notifyPeer", [("peer", peer)])
                case .notifyUsers:
                return ("notifyUsers", [])
                case .notifyChats:
                return ("notifyChats", [])
                case .notifyBroadcasts:
                return ("notifyBroadcasts", [])
    }
    }
    
        public static func parse_notifyPeer(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotifyPeer.notifyPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_notifyUsers(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyUsers
        }
        public static func parse_notifyChats(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyChats
        }
        public static func parse_notifyBroadcasts(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyBroadcasts
        }
    
    }
    public enum InputPrivacyKey: TypeConstructorDescription {
        case inputPrivacyKeyStatusTimestamp
        case inputPrivacyKeyChatInvite
        case inputPrivacyKeyPhoneCall
        case inputPrivacyKeyPhoneP2P
        case inputPrivacyKeyForwards
        case inputPrivacyKeyProfilePhoto
        case inputPrivacyKeyPhoneNumber
        case inputPrivacyKeyAddedByPhone
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPrivacyKeyStatusTimestamp:
                    if boxed {
                        buffer.appendInt32(1335282456)
                    }
                    
                    break
                case .inputPrivacyKeyChatInvite:
                    if boxed {
                        buffer.appendInt32(-1107622874)
                    }
                    
                    break
                case .inputPrivacyKeyPhoneCall:
                    if boxed {
                        buffer.appendInt32(-88417185)
                    }
                    
                    break
                case .inputPrivacyKeyPhoneP2P:
                    if boxed {
                        buffer.appendInt32(-610373422)
                    }
                    
                    break
                case .inputPrivacyKeyForwards:
                    if boxed {
                        buffer.appendInt32(-1529000952)
                    }
                    
                    break
                case .inputPrivacyKeyProfilePhoto:
                    if boxed {
                        buffer.appendInt32(1461304012)
                    }
                    
                    break
                case .inputPrivacyKeyPhoneNumber:
                    if boxed {
                        buffer.appendInt32(55761658)
                    }
                    
                    break
                case .inputPrivacyKeyAddedByPhone:
                    if boxed {
                        buffer.appendInt32(-786326563)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPrivacyKeyStatusTimestamp:
                return ("inputPrivacyKeyStatusTimestamp", [])
                case .inputPrivacyKeyChatInvite:
                return ("inputPrivacyKeyChatInvite", [])
                case .inputPrivacyKeyPhoneCall:
                return ("inputPrivacyKeyPhoneCall", [])
                case .inputPrivacyKeyPhoneP2P:
                return ("inputPrivacyKeyPhoneP2P", [])
                case .inputPrivacyKeyForwards:
                return ("inputPrivacyKeyForwards", [])
                case .inputPrivacyKeyProfilePhoto:
                return ("inputPrivacyKeyProfilePhoto", [])
                case .inputPrivacyKeyPhoneNumber:
                return ("inputPrivacyKeyPhoneNumber", [])
                case .inputPrivacyKeyAddedByPhone:
                return ("inputPrivacyKeyAddedByPhone", [])
    }
    }
    
        public static func parse_inputPrivacyKeyStatusTimestamp(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyStatusTimestamp
        }
        public static func parse_inputPrivacyKeyChatInvite(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyChatInvite
        }
        public static func parse_inputPrivacyKeyPhoneCall(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyPhoneCall
        }
        public static func parse_inputPrivacyKeyPhoneP2P(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyPhoneP2P
        }
        public static func parse_inputPrivacyKeyForwards(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyForwards
        }
        public static func parse_inputPrivacyKeyProfilePhoto(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyProfilePhoto
        }
        public static func parse_inputPrivacyKeyPhoneNumber(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyPhoneNumber
        }
        public static func parse_inputPrivacyKeyAddedByPhone(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyAddedByPhone
        }
    
    }
    public enum ReplyMarkup: TypeConstructorDescription {
        case replyKeyboardHide(flags: Int32)
        case replyKeyboardForceReply(flags: Int32)
        case replyKeyboardMarkup(flags: Int32, rows: [Api.KeyboardButtonRow])
        case replyInlineMarkup(rows: [Api.KeyboardButtonRow])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .replyKeyboardHide(let flags):
                    if boxed {
                        buffer.appendInt32(-1606526075)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .replyKeyboardForceReply(let flags):
                    if boxed {
                        buffer.appendInt32(-200242528)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .replyKeyboardMarkup(let flags, let rows):
                    if boxed {
                        buffer.appendInt32(889353612)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rows.count))
                    for item in rows {
                        item.serialize(buffer, true)
                    }
                    break
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .replyKeyboardHide(let flags):
                return ("replyKeyboardHide", [("flags", flags)])
                case .replyKeyboardForceReply(let flags):
                return ("replyKeyboardForceReply", [("flags", flags)])
                case .replyKeyboardMarkup(let flags, let rows):
                return ("replyKeyboardMarkup", [("flags", flags), ("rows", rows)])
                case .replyInlineMarkup(let rows):
                return ("replyInlineMarkup", [("rows", rows)])
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
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyKeyboardForceReply(flags: _1!)
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReplyMarkup.replyKeyboardMarkup(flags: _1!, rows: _2!)
            }
            else {
                return nil
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
    
    }
    public enum EmojiKeywordsDifference: TypeConstructorDescription {
        case emojiKeywordsDifference(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiKeywordsDifference(let langCode, let fromVersion, let version, let keywords):
                    if boxed {
                        buffer.appendInt32(1556570557)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keywords.count))
                    for item in keywords {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiKeywordsDifference(let langCode, let fromVersion, let version, let keywords):
                return ("emojiKeywordsDifference", [("langCode", langCode), ("fromVersion", fromVersion), ("version", version), ("keywords", keywords)])
    }
    }
    
        public static func parse_emojiKeywordsDifference(_ reader: BufferReader) -> EmojiKeywordsDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.EmojiKeyword]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiKeyword.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.EmojiKeywordsDifference.emojiKeywordsDifference(langCode: _1!, fromVersion: _2!, version: _3!, keywords: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum HighScore: TypeConstructorDescription {
        case highScore(pos: Int32, userId: Int32, score: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .highScore(let pos, let userId, let score):
                    if boxed {
                        buffer.appendInt32(1493171408)
                    }
                    serializeInt32(pos, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .highScore(let pos, let userId, let score):
                return ("highScore", [("pos", pos), ("userId", userId), ("score", score)])
    }
    }
    
        public static func parse_highScore(_ reader: BufferReader) -> HighScore? {
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
                return Api.HighScore.highScore(pos: _1!, userId: _2!, score: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum TopPeer: TypeConstructorDescription {
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
                return ("topPeer", [("peer", peer), ("rating", rating)])
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
    public enum SecureValue: TypeConstructorDescription {
        case secureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData, let hash):
                    if boxed {
                        buffer.appendInt32(411017418)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {data!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {frontSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {reverseSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {selfie!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(translation!.count))
                    for item in translation! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(files!.count))
                    for item in files! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {plainData!.serialize(buffer, true)}
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData, let hash):
                return ("secureValue", [("flags", flags), ("type", type), ("data", data), ("frontSide", frontSide), ("reverseSide", reverseSide), ("selfie", selfie), ("translation", translation), ("files", files), ("plainData", plainData), ("hash", hash)])
    }
    }
    
        public static func parse_secureValue(_ reader: BufferReader) -> SecureValue? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _3: Api.SecureData?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureData
            } }
            var _4: Api.SecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _5: Api.SecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _6: Api.SecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _7: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
            } }
            var _8: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
            } }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
            } }
            var _10: Buffer?
            _10 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.SecureValue.secureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9, hash: _10!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecureValueHash: TypeConstructorDescription {
        case secureValueHash(type: Api.SecureValueType, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueHash(let type, let hash):
                    if boxed {
                        buffer.appendInt32(-316748368)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueHash(let type, let hash):
                return ("secureValueHash", [("type", type), ("hash", hash)])
    }
    }
    
        public static func parse_secureValueHash(_ reader: BufferReader) -> SecureValueHash? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureValueHash.secureValueHash(type: _1!, hash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ContactBlocked: TypeConstructorDescription {
        case contactBlocked(userId: Int32, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contactBlocked(let userId, let date):
                    if boxed {
                        buffer.appendInt32(1444661369)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contactBlocked(let userId, let date):
                return ("contactBlocked", [("userId", userId), ("date", date)])
    }
    }
    
        public static func parse_contactBlocked(_ reader: BufferReader) -> ContactBlocked? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ContactBlocked.contactBlocked(userId: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PageListItem: TypeConstructorDescription {
        case pageListItemText(text: Api.RichText)
        case pageListItemBlocks(blocks: [Api.PageBlock])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageListItemText(let text):
                    if boxed {
                        buffer.appendInt32(-1188055347)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageListItemBlocks(let blocks):
                    if boxed {
                        buffer.appendInt32(635466748)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocks.count))
                    for item in blocks {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageListItemText(let text):
                return ("pageListItemText", [("text", text)])
                case .pageListItemBlocks(let blocks):
                return ("pageListItemBlocks", [("blocks", blocks)])
    }
    }
    
        public static func parse_pageListItemText(_ reader: BufferReader) -> PageListItem? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageListItem.pageListItemText(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageListItemBlocks(_ reader: BufferReader) -> PageListItem? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageListItem.pageListItemBlocks(blocks: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputUser: TypeConstructorDescription {
        case inputUserEmpty
        case inputUserSelf
        case inputUser(userId: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputUserEmpty:
                    if boxed {
                        buffer.appendInt32(-1182234929)
                    }
                    
                    break
                case .inputUserSelf:
                    if boxed {
                        buffer.appendInt32(-138301121)
                    }
                    
                    break
                case .inputUser(let userId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-668391402)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputUserEmpty:
                return ("inputUserEmpty", [])
                case .inputUserSelf:
                return ("inputUserSelf", [])
                case .inputUser(let userId, let accessHash):
                return ("inputUser", [("userId", userId), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputUserEmpty(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserEmpty
        }
        public static func parse_inputUserSelf(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserSelf
        }
        public static func parse_inputUser(_ reader: BufferReader) -> InputUser? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputUser.inputUser(userId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Page: TypeConstructorDescription {
        case page(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .page(let flags, let url, let blocks, let photos, let documents):
                    if boxed {
                        buffer.appendInt32(-1366746132)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocks.count))
                    for item in blocks {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .page(let flags, let url, let blocks, let photos, let documents):
                return ("page", [("flags", flags), ("url", url), ("blocks", blocks), ("photos", photos), ("documents", documents)])
    }
    }
    
        public static func parse_page(_ reader: BufferReader) -> Page? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _4: [Api.Photo]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _5: [Api.Document]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Page.page(flags: _1!, url: _2!, blocks: _3!, photos: _4!, documents: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecureCredentialsEncrypted: TypeConstructorDescription {
        case secureCredentialsEncrypted(data: Buffer, hash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureCredentialsEncrypted(let data, let hash, let secret):
                    if boxed {
                        buffer.appendInt32(871426631)
                    }
                    serializeBytes(data, buffer: buffer, boxed: false)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureCredentialsEncrypted(let data, let hash, let secret):
                return ("secureCredentialsEncrypted", [("data", data), ("hash", hash), ("secret", secret)])
    }
    }
    
        public static func parse_secureCredentialsEncrypted(_ reader: BufferReader) -> SecureCredentialsEncrypted? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureCredentialsEncrypted.secureCredentialsEncrypted(data: _1!, hash: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelLocation: TypeConstructorDescription {
        case channelLocationEmpty
        case channelLocation(geoPoint: Api.GeoPoint, address: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelLocationEmpty:
                    if boxed {
                        buffer.appendInt32(-1078612597)
                    }
                    
                    break
                case .channelLocation(let geoPoint, let address):
                    if boxed {
                        buffer.appendInt32(547062491)
                    }
                    geoPoint.serialize(buffer, true)
                    serializeString(address, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelLocationEmpty:
                return ("channelLocationEmpty", [])
                case .channelLocation(let geoPoint, let address):
                return ("channelLocation", [("geoPoint", geoPoint), ("address", address)])
    }
    }
    
        public static func parse_channelLocationEmpty(_ reader: BufferReader) -> ChannelLocation? {
            return Api.ChannelLocation.channelLocationEmpty
        }
        public static func parse_channelLocation(_ reader: BufferReader) -> ChannelLocation? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelLocation.channelLocation(geoPoint: _1!, address: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageRange: TypeConstructorDescription {
        case messageRange(minId: Int32, maxId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageRange(let minId, let maxId):
                    if boxed {
                        buffer.appendInt32(182649427)
                    }
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageRange(let minId, let maxId):
                return ("messageRange", [("minId", minId), ("maxId", maxId)])
    }
    }
    
        public static func parse_messageRange(_ reader: BufferReader) -> MessageRange? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageRange.messageRange(minId: _1!, maxId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Config: TypeConstructorDescription {
        case config(flags: Int32, date: Int32, expires: Int32, testMode: Api.Bool, thisDc: Int32, dcOptions: [Api.DcOption], dcTxtDomainName: String, chatSizeMax: Int32, megagroupSizeMax: Int32, forwardedCountMax: Int32, onlineUpdatePeriodMs: Int32, offlineBlurTimeoutMs: Int32, offlineIdleTimeoutMs: Int32, onlineCloudTimeoutMs: Int32, notifyCloudDelayMs: Int32, notifyDefaultDelayMs: Int32, pushChatPeriodMs: Int32, pushChatLimit: Int32, savedGifsLimit: Int32, editTimeLimit: Int32, revokeTimeLimit: Int32, revokePmTimeLimit: Int32, ratingEDecay: Int32, stickersRecentLimit: Int32, stickersFavedLimit: Int32, channelsReadMediaPeriod: Int32, tmpSessions: Int32?, pinnedDialogsCountMax: Int32, pinnedInfolderCountMax: Int32, callReceiveTimeoutMs: Int32, callRingTimeoutMs: Int32, callConnectTimeoutMs: Int32, callPacketTimeoutMs: Int32, meUrlPrefix: String, autoupdateUrlPrefix: String?, gifSearchUsername: String?, venueSearchUsername: String?, imgSearchUsername: String?, staticMapsProvider: String?, captionLengthMax: Int32, messageLengthMax: Int32, webfileDcId: Int32, suggestedLangCode: String?, langPackVersion: Int32?, baseLangPackVersion: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .config(let flags, let date, let expires, let testMode, let thisDc, let dcOptions, let dcTxtDomainName, let chatSizeMax, let megagroupSizeMax, let forwardedCountMax, let onlineUpdatePeriodMs, let offlineBlurTimeoutMs, let offlineIdleTimeoutMs, let onlineCloudTimeoutMs, let notifyCloudDelayMs, let notifyDefaultDelayMs, let pushChatPeriodMs, let pushChatLimit, let savedGifsLimit, let editTimeLimit, let revokeTimeLimit, let revokePmTimeLimit, let ratingEDecay, let stickersRecentLimit, let stickersFavedLimit, let channelsReadMediaPeriod, let tmpSessions, let pinnedDialogsCountMax, let pinnedInfolderCountMax, let callReceiveTimeoutMs, let callRingTimeoutMs, let callConnectTimeoutMs, let callPacketTimeoutMs, let meUrlPrefix, let autoupdateUrlPrefix, let gifSearchUsername, let venueSearchUsername, let imgSearchUsername, let staticMapsProvider, let captionLengthMax, let messageLengthMax, let webfileDcId, let suggestedLangCode, let langPackVersion, let baseLangPackVersion):
                    if boxed {
                        buffer.appendInt32(856375399)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    testMode.serialize(buffer, true)
                    serializeInt32(thisDc, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dcOptions.count))
                    for item in dcOptions {
                        item.serialize(buffer, true)
                    }
                    serializeString(dcTxtDomainName, buffer: buffer, boxed: false)
                    serializeInt32(chatSizeMax, buffer: buffer, boxed: false)
                    serializeInt32(megagroupSizeMax, buffer: buffer, boxed: false)
                    serializeInt32(forwardedCountMax, buffer: buffer, boxed: false)
                    serializeInt32(onlineUpdatePeriodMs, buffer: buffer, boxed: false)
                    serializeInt32(offlineBlurTimeoutMs, buffer: buffer, boxed: false)
                    serializeInt32(offlineIdleTimeoutMs, buffer: buffer, boxed: false)
                    serializeInt32(onlineCloudTimeoutMs, buffer: buffer, boxed: false)
                    serializeInt32(notifyCloudDelayMs, buffer: buffer, boxed: false)
                    serializeInt32(notifyDefaultDelayMs, buffer: buffer, boxed: false)
                    serializeInt32(pushChatPeriodMs, buffer: buffer, boxed: false)
                    serializeInt32(pushChatLimit, buffer: buffer, boxed: false)
                    serializeInt32(savedGifsLimit, buffer: buffer, boxed: false)
                    serializeInt32(editTimeLimit, buffer: buffer, boxed: false)
                    serializeInt32(revokeTimeLimit, buffer: buffer, boxed: false)
                    serializeInt32(revokePmTimeLimit, buffer: buffer, boxed: false)
                    serializeInt32(ratingEDecay, buffer: buffer, boxed: false)
                    serializeInt32(stickersRecentLimit, buffer: buffer, boxed: false)
                    serializeInt32(stickersFavedLimit, buffer: buffer, boxed: false)
                    serializeInt32(channelsReadMediaPeriod, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(tmpSessions!, buffer: buffer, boxed: false)}
                    serializeInt32(pinnedDialogsCountMax, buffer: buffer, boxed: false)
                    serializeInt32(pinnedInfolderCountMax, buffer: buffer, boxed: false)
                    serializeInt32(callReceiveTimeoutMs, buffer: buffer, boxed: false)
                    serializeInt32(callRingTimeoutMs, buffer: buffer, boxed: false)
                    serializeInt32(callConnectTimeoutMs, buffer: buffer, boxed: false)
                    serializeInt32(callPacketTimeoutMs, buffer: buffer, boxed: false)
                    serializeString(meUrlPrefix, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {serializeString(autoupdateUrlPrefix!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeString(gifSearchUsername!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeString(venueSearchUsername!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(imgSearchUsername!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 12) != 0 {serializeString(staticMapsProvider!, buffer: buffer, boxed: false)}
                    serializeInt32(captionLengthMax, buffer: buffer, boxed: false)
                    serializeInt32(messageLengthMax, buffer: buffer, boxed: false)
                    serializeInt32(webfileDcId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(suggestedLangCode!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(langPackVersion!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(baseLangPackVersion!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .config(let flags, let date, let expires, let testMode, let thisDc, let dcOptions, let dcTxtDomainName, let chatSizeMax, let megagroupSizeMax, let forwardedCountMax, let onlineUpdatePeriodMs, let offlineBlurTimeoutMs, let offlineIdleTimeoutMs, let onlineCloudTimeoutMs, let notifyCloudDelayMs, let notifyDefaultDelayMs, let pushChatPeriodMs, let pushChatLimit, let savedGifsLimit, let editTimeLimit, let revokeTimeLimit, let revokePmTimeLimit, let ratingEDecay, let stickersRecentLimit, let stickersFavedLimit, let channelsReadMediaPeriod, let tmpSessions, let pinnedDialogsCountMax, let pinnedInfolderCountMax, let callReceiveTimeoutMs, let callRingTimeoutMs, let callConnectTimeoutMs, let callPacketTimeoutMs, let meUrlPrefix, let autoupdateUrlPrefix, let gifSearchUsername, let venueSearchUsername, let imgSearchUsername, let staticMapsProvider, let captionLengthMax, let messageLengthMax, let webfileDcId, let suggestedLangCode, let langPackVersion, let baseLangPackVersion):
                return ("config", [("flags", flags), ("date", date), ("expires", expires), ("testMode", testMode), ("thisDc", thisDc), ("dcOptions", dcOptions), ("dcTxtDomainName", dcTxtDomainName), ("chatSizeMax", chatSizeMax), ("megagroupSizeMax", megagroupSizeMax), ("forwardedCountMax", forwardedCountMax), ("onlineUpdatePeriodMs", onlineUpdatePeriodMs), ("offlineBlurTimeoutMs", offlineBlurTimeoutMs), ("offlineIdleTimeoutMs", offlineIdleTimeoutMs), ("onlineCloudTimeoutMs", onlineCloudTimeoutMs), ("notifyCloudDelayMs", notifyCloudDelayMs), ("notifyDefaultDelayMs", notifyDefaultDelayMs), ("pushChatPeriodMs", pushChatPeriodMs), ("pushChatLimit", pushChatLimit), ("savedGifsLimit", savedGifsLimit), ("editTimeLimit", editTimeLimit), ("revokeTimeLimit", revokeTimeLimit), ("revokePmTimeLimit", revokePmTimeLimit), ("ratingEDecay", ratingEDecay), ("stickersRecentLimit", stickersRecentLimit), ("stickersFavedLimit", stickersFavedLimit), ("channelsReadMediaPeriod", channelsReadMediaPeriod), ("tmpSessions", tmpSessions), ("pinnedDialogsCountMax", pinnedDialogsCountMax), ("pinnedInfolderCountMax", pinnedInfolderCountMax), ("callReceiveTimeoutMs", callReceiveTimeoutMs), ("callRingTimeoutMs", callRingTimeoutMs), ("callConnectTimeoutMs", callConnectTimeoutMs), ("callPacketTimeoutMs", callPacketTimeoutMs), ("meUrlPrefix", meUrlPrefix), ("autoupdateUrlPrefix", autoupdateUrlPrefix), ("gifSearchUsername", gifSearchUsername), ("venueSearchUsername", venueSearchUsername), ("imgSearchUsername", imgSearchUsername), ("staticMapsProvider", staticMapsProvider), ("captionLengthMax", captionLengthMax), ("messageLengthMax", messageLengthMax), ("webfileDcId", webfileDcId), ("suggestedLangCode", suggestedLangCode), ("langPackVersion", langPackVersion), ("baseLangPackVersion", baseLangPackVersion)])
    }
    }
    
        public static func parse_config(_ reader: BufferReader) -> Config? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Bool?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.DcOption]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DcOption.self)
            }
            var _7: String?
            _7 = parseString(reader)
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Int32?
            _13 = reader.readInt32()
            var _14: Int32?
            _14 = reader.readInt32()
            var _15: Int32?
            _15 = reader.readInt32()
            var _16: Int32?
            _16 = reader.readInt32()
            var _17: Int32?
            _17 = reader.readInt32()
            var _18: Int32?
            _18 = reader.readInt32()
            var _19: Int32?
            _19 = reader.readInt32()
            var _20: Int32?
            _20 = reader.readInt32()
            var _21: Int32?
            _21 = reader.readInt32()
            var _22: Int32?
            _22 = reader.readInt32()
            var _23: Int32?
            _23 = reader.readInt32()
            var _24: Int32?
            _24 = reader.readInt32()
            var _25: Int32?
            _25 = reader.readInt32()
            var _26: Int32?
            _26 = reader.readInt32()
            var _27: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_27 = reader.readInt32() }
            var _28: Int32?
            _28 = reader.readInt32()
            var _29: Int32?
            _29 = reader.readInt32()
            var _30: Int32?
            _30 = reader.readInt32()
            var _31: Int32?
            _31 = reader.readInt32()
            var _32: Int32?
            _32 = reader.readInt32()
            var _33: Int32?
            _33 = reader.readInt32()
            var _34: String?
            _34 = parseString(reader)
            var _35: String?
            if Int(_1!) & Int(1 << 7) != 0 {_35 = parseString(reader) }
            var _36: String?
            if Int(_1!) & Int(1 << 9) != 0 {_36 = parseString(reader) }
            var _37: String?
            if Int(_1!) & Int(1 << 10) != 0 {_37 = parseString(reader) }
            var _38: String?
            if Int(_1!) & Int(1 << 11) != 0 {_38 = parseString(reader) }
            var _39: String?
            if Int(_1!) & Int(1 << 12) != 0 {_39 = parseString(reader) }
            var _40: Int32?
            _40 = reader.readInt32()
            var _41: Int32?
            _41 = reader.readInt32()
            var _42: Int32?
            _42 = reader.readInt32()
            var _43: String?
            if Int(_1!) & Int(1 << 2) != 0 {_43 = parseString(reader) }
            var _44: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_44 = reader.readInt32() }
            var _45: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_45 = reader.readInt32() }
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
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            let _c18 = _18 != nil
            let _c19 = _19 != nil
            let _c20 = _20 != nil
            let _c21 = _21 != nil
            let _c22 = _22 != nil
            let _c23 = _23 != nil
            let _c24 = _24 != nil
            let _c25 = _25 != nil
            let _c26 = _26 != nil
            let _c27 = (Int(_1!) & Int(1 << 0) == 0) || _27 != nil
            let _c28 = _28 != nil
            let _c29 = _29 != nil
            let _c30 = _30 != nil
            let _c31 = _31 != nil
            let _c32 = _32 != nil
            let _c33 = _33 != nil
            let _c34 = _34 != nil
            let _c35 = (Int(_1!) & Int(1 << 7) == 0) || _35 != nil
            let _c36 = (Int(_1!) & Int(1 << 9) == 0) || _36 != nil
            let _c37 = (Int(_1!) & Int(1 << 10) == 0) || _37 != nil
            let _c38 = (Int(_1!) & Int(1 << 11) == 0) || _38 != nil
            let _c39 = (Int(_1!) & Int(1 << 12) == 0) || _39 != nil
            let _c40 = _40 != nil
            let _c41 = _41 != nil
            let _c42 = _42 != nil
            let _c43 = (Int(_1!) & Int(1 << 2) == 0) || _43 != nil
            let _c44 = (Int(_1!) & Int(1 << 2) == 0) || _44 != nil
            let _c45 = (Int(_1!) & Int(1 << 2) == 0) || _45 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 && _c35 && _c36 && _c37 && _c38 && _c39 && _c40 && _c41 && _c42 && _c43 && _c44 && _c45 {
                return Api.Config.config(flags: _1!, date: _2!, expires: _3!, testMode: _4!, thisDc: _5!, dcOptions: _6!, dcTxtDomainName: _7!, chatSizeMax: _8!, megagroupSizeMax: _9!, forwardedCountMax: _10!, onlineUpdatePeriodMs: _11!, offlineBlurTimeoutMs: _12!, offlineIdleTimeoutMs: _13!, onlineCloudTimeoutMs: _14!, notifyCloudDelayMs: _15!, notifyDefaultDelayMs: _16!, pushChatPeriodMs: _17!, pushChatLimit: _18!, savedGifsLimit: _19!, editTimeLimit: _20!, revokeTimeLimit: _21!, revokePmTimeLimit: _22!, ratingEDecay: _23!, stickersRecentLimit: _24!, stickersFavedLimit: _25!, channelsReadMediaPeriod: _26!, tmpSessions: _27, pinnedDialogsCountMax: _28!, pinnedInfolderCountMax: _29!, callReceiveTimeoutMs: _30!, callRingTimeoutMs: _31!, callConnectTimeoutMs: _32!, callPacketTimeoutMs: _33!, meUrlPrefix: _34!, autoupdateUrlPrefix: _35, gifSearchUsername: _36, venueSearchUsername: _37, imgSearchUsername: _38, staticMapsProvider: _39, captionLengthMax: _40!, messageLengthMax: _41!, webfileDcId: _42!, suggestedLangCode: _43, langPackVersion: _44, baseLangPackVersion: _45)
            }
            else {
                return nil
            }
        }
    
    }
    public enum TopPeerCategoryPeers: TypeConstructorDescription {
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
                return ("topPeerCategoryPeers", [("category", category), ("count", count), ("peers", peers)])
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
    public enum Game: TypeConstructorDescription {
        case game(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .game(let flags, let id, let accessHash, let shortName, let title, let description, let photo, let document):
                    if boxed {
                        buffer.appendInt32(-1107729093)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .game(let flags, let id, let accessHash, let shortName, let title, let description, let photo, let document):
                return ("game", [("flags", flags), ("id", id), ("accessHash", accessHash), ("shortName", shortName), ("title", title), ("description", description), ("photo", photo), ("document", document)])
    }
    }
    
        public static func parse_game(_ reader: BufferReader) -> Game? {
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Game.game(flags: _1!, id: _2!, accessHash: _3!, shortName: _4!, title: _5!, description: _6!, photo: _7!, document: _8)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatAdminRights: TypeConstructorDescription {
        case chatAdminRights(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatAdminRights(let flags):
                    if boxed {
                        buffer.appendInt32(1605510357)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatAdminRights(let flags):
                return ("chatAdminRights", [("flags", flags)])
    }
    }
    
        public static func parse_chatAdminRights(_ reader: BufferReader) -> ChatAdminRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatAdminRights.chatAdminRights(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SecurePasswordKdfAlgo: TypeConstructorDescription {
        case securePasswordKdfAlgoUnknown
        case securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: Buffer)
        case securePasswordKdfAlgoSHA512(salt: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .securePasswordKdfAlgoUnknown:
                    if boxed {
                        buffer.appendInt32(4883767)
                    }
                    
                    break
                case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let salt):
                    if boxed {
                        buffer.appendInt32(-1141711456)
                    }
                    serializeBytes(salt, buffer: buffer, boxed: false)
                    break
                case .securePasswordKdfAlgoSHA512(let salt):
                    if boxed {
                        buffer.appendInt32(-2042159726)
                    }
                    serializeBytes(salt, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .securePasswordKdfAlgoUnknown:
                return ("securePasswordKdfAlgoUnknown", [])
                case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let salt):
                return ("securePasswordKdfAlgoPBKDF2HMACSHA512iter100000", [("salt", salt)])
                case .securePasswordKdfAlgoSHA512(let salt):
                return ("securePasswordKdfAlgoSHA512", [("salt", salt)])
    }
    }
    
        public static func parse_securePasswordKdfAlgoUnknown(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoUnknown
        }
        public static func parse_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoSHA512(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoSHA512(salt: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BotCommand: TypeConstructorDescription {
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
                return ("botCommand", [("command", command), ("description", description)])
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
    public enum CdnPublicKey: TypeConstructorDescription {
        case cdnPublicKey(dcId: Int32, publicKey: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .cdnPublicKey(let dcId, let publicKey):
                    if boxed {
                        buffer.appendInt32(-914167110)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .cdnPublicKey(let dcId, let publicKey):
                return ("cdnPublicKey", [("dcId", dcId), ("publicKey", publicKey)])
    }
    }
    
        public static func parse_cdnPublicKey(_ reader: BufferReader) -> CdnPublicKey? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.CdnPublicKey.cdnPublicKey(dcId: _1!, publicKey: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputGame: TypeConstructorDescription {
        case inputGameID(id: Int64, accessHash: Int64)
        case inputGameShortName(botId: Api.InputUser, shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputGameID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(53231223)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputGameShortName(let botId, let shortName):
                    if boxed {
                        buffer.appendInt32(-1020139510)
                    }
                    botId.serialize(buffer, true)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputGameID(let id, let accessHash):
                return ("inputGameID", [("id", id), ("accessHash", accessHash)])
                case .inputGameShortName(let botId, let shortName):
                return ("inputGameShortName", [("botId", botId), ("shortName", shortName)])
    }
    }
    
        public static func parse_inputGameID(_ reader: BufferReader) -> InputGame? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGame.inputGameID(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputGameShortName(_ reader: BufferReader) -> InputGame? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGame.inputGameShortName(botId: _1!, shortName: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputMessage: TypeConstructorDescription {
        case inputMessageID(id: Int32)
        case inputMessageReplyTo(id: Int32)
        case inputMessagePinned
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMessageID(let id):
                    if boxed {
                        buffer.appendInt32(-1502174430)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .inputMessageReplyTo(let id):
                    if boxed {
                        buffer.appendInt32(-1160215659)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .inputMessagePinned:
                    if boxed {
                        buffer.appendInt32(-2037963464)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMessageID(let id):
                return ("inputMessageID", [("id", id)])
                case .inputMessageReplyTo(let id):
                return ("inputMessageReplyTo", [("id", id)])
                case .inputMessagePinned:
                return ("inputMessagePinned", [])
    }
    }
    
        public static func parse_inputMessageID(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageID(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessageReplyTo(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageReplyTo(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessagePinned(_ reader: BufferReader) -> InputMessage? {
            return Api.InputMessage.inputMessagePinned
        }
    
    }
    public enum PhoneCallProtocol: TypeConstructorDescription {
        case phoneCallProtocol(flags: Int32, minLayer: Int32, maxLayer: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCallProtocol(let flags, let minLayer, let maxLayer):
                    if boxed {
                        buffer.appendInt32(-1564789301)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(minLayer, buffer: buffer, boxed: false)
                    serializeInt32(maxLayer, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCallProtocol(let flags, let minLayer, let maxLayer):
                return ("phoneCallProtocol", [("flags", flags), ("minLayer", minLayer), ("maxLayer", maxLayer)])
    }
    }
    
        public static func parse_phoneCallProtocol(_ reader: BufferReader) -> PhoneCallProtocol? {
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
                return Api.PhoneCallProtocol.phoneCallProtocol(flags: _1!, minLayer: _2!, maxLayer: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageFwdAuthor: TypeConstructorDescription {
        case messageFwdAuthor(channelId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageFwdAuthor(let channelId):
                    if boxed {
                        buffer.appendInt32(-1567175714)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageFwdAuthor(let channelId):
                return ("messageFwdAuthor", [("channelId", channelId)])
    }
    }
    
        public static func parse_messageFwdAuthor(_ reader: BufferReader) -> MessageFwdAuthor? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageFwdAuthor.messageFwdAuthor(channelId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WallPaper: TypeConstructorDescription {
        case wallPaper(id: Int64, flags: Int32, accessHash: Int64, slug: String, document: Api.Document, settings: Api.WallPaperSettings?)
        case wallPaperNoFile(flags: Int32, settings: Api.WallPaperSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .wallPaper(let id, let flags, let accessHash, let slug, let document, let settings):
                    if boxed {
                        buffer.appendInt32(-1539849235)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {settings!.serialize(buffer, true)}
                    break
                case .wallPaperNoFile(let flags, let settings):
                    if boxed {
                        buffer.appendInt32(-1963717851)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {settings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .wallPaper(let id, let flags, let accessHash, let slug, let document, let settings):
                return ("wallPaper", [("id", id), ("flags", flags), ("accessHash", accessHash), ("slug", slug), ("document", document), ("settings", settings)])
                case .wallPaperNoFile(let flags, let settings):
                return ("wallPaperNoFile", [("flags", flags), ("settings", settings)])
    }
    }
    
        public static func parse_wallPaper(_ reader: BufferReader) -> WallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.Document?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _6: Api.WallPaperSettings?
            if Int(_2!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_2!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.WallPaper.wallPaper(id: _1!, flags: _2!, accessHash: _3!, slug: _4!, document: _5!, settings: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_wallPaperNoFile(_ reader: BufferReader) -> WallPaper? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.WallPaperSettings?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WallPaper.wallPaperNoFile(flags: _1!, settings: _2)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Invoice: TypeConstructorDescription {
        case invoice(flags: Int32, currency: String, prices: [Api.LabeledPrice])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .invoice(let flags, let currency, let prices):
                    if boxed {
                        buffer.appendInt32(-1022713000)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .invoice(let flags, let currency, let prices):
                return ("invoice", [("flags", flags), ("currency", currency), ("prices", prices)])
    }
    }
    
        public static func parse_invoice(_ reader: BufferReader) -> Invoice? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.Invoice.invoice(flags: _1!, currency: _2!, prices: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PeerSettings: TypeConstructorDescription {
        case peerSettings(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerSettings(let flags):
                    if boxed {
                        buffer.appendInt32(-2122045747)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerSettings(let flags):
                return ("peerSettings", [("flags", flags)])
    }
    }
    
        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.PeerSettings.peerSettings(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputChatPhoto: TypeConstructorDescription {
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(file: Api.InputFile)
        case inputChatPhoto(id: Api.InputPhoto)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChatPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(480546647)
                    }
                    
                    break
                case .inputChatUploadedPhoto(let file):
                    if boxed {
                        buffer.appendInt32(-1837345356)
                    }
                    file.serialize(buffer, true)
                    break
                case .inputChatPhoto(let id):
                    if boxed {
                        buffer.appendInt32(-1991004873)
                    }
                    id.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChatPhotoEmpty:
                return ("inputChatPhotoEmpty", [])
                case .inputChatUploadedPhoto(let file):
                return ("inputChatUploadedPhoto", [("file", file)])
                case .inputChatPhoto(let id):
                return ("inputChatPhoto", [("id", id)])
    }
    }
    
        public static func parse_inputChatPhotoEmpty(_ reader: BufferReader) -> InputChatPhoto? {
            return Api.InputChatPhoto.inputChatPhotoEmpty
        }
        public static func parse_inputChatUploadedPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Api.InputFile?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatPhoto.inputChatUploadedPhoto(file: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputChatPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatPhoto.inputChatPhoto(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentCharge: TypeConstructorDescription {
        case paymentCharge(id: String, providerChargeId: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentCharge(let id, let providerChargeId):
                    if boxed {
                        buffer.appendInt32(-368917890)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(providerChargeId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentCharge(let id, let providerChargeId):
                return ("paymentCharge", [("id", id), ("providerChargeId", providerChargeId)])
    }
    }
    
        public static func parse_paymentCharge(_ reader: BufferReader) -> PaymentCharge? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PaymentCharge.paymentCharge(id: _1!, providerChargeId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Updates: TypeConstructorDescription {
        case updatesTooLong
        case updateShortMessage(flags: Int32, id: Int32, userId: Int32, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int32?, replyToMsgId: Int32?, entities: [Api.MessageEntity]?)
        case updateShortChatMessage(flags: Int32, id: Int32, fromId: Int32, chatId: Int32, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int32?, replyToMsgId: Int32?, entities: [Api.MessageEntity]?)
        case updateShort(update: Api.Update, date: Int32)
        case updatesCombined(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seqStart: Int32, seq: Int32)
        case updates(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seq: Int32)
        case updateShortSentMessage(flags: Int32, id: Int32, pts: Int32, ptsCount: Int32, date: Int32, media: Api.MessageMedia?, entities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .updatesTooLong:
                    if boxed {
                        buffer.appendInt32(-484987010)
                    }
                    
                    break
                case .updateShortMessage(let flags, let id, let userId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyToMsgId, let entities):
                    if boxed {
                        buffer.appendInt32(-1857044719)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .updateShortChatMessage(let flags, let id, let fromId, let chatId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyToMsgId, let entities):
                    if boxed {
                        buffer.appendInt32(377562760)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(fromId, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .updateShort(let update, let date):
                    if boxed {
                        buffer.appendInt32(2027216577)
                    }
                    update.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updatesCombined(let updates, let users, let chats, let date, let seqStart, let seq):
                    if boxed {
                        buffer.appendInt32(1918567619)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(updates.count))
                    for item in updates {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seqStart, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .updates(let updates, let users, let chats, let date, let seq):
                    if boxed {
                        buffer.appendInt32(1957577280)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(updates.count))
                    for item in updates {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .updateShortSentMessage(let flags, let id, let pts, let ptsCount, let date, let media, let entities):
                    if boxed {
                        buffer.appendInt32(301019932)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .updatesTooLong:
                return ("updatesTooLong", [])
                case .updateShortMessage(let flags, let id, let userId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyToMsgId, let entities):
                return ("updateShortMessage", [("flags", flags), ("id", id), ("userId", userId), ("message", message), ("pts", pts), ("ptsCount", ptsCount), ("date", date), ("fwdFrom", fwdFrom), ("viaBotId", viaBotId), ("replyToMsgId", replyToMsgId), ("entities", entities)])
                case .updateShortChatMessage(let flags, let id, let fromId, let chatId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyToMsgId, let entities):
                return ("updateShortChatMessage", [("flags", flags), ("id", id), ("fromId", fromId), ("chatId", chatId), ("message", message), ("pts", pts), ("ptsCount", ptsCount), ("date", date), ("fwdFrom", fwdFrom), ("viaBotId", viaBotId), ("replyToMsgId", replyToMsgId), ("entities", entities)])
                case .updateShort(let update, let date):
                return ("updateShort", [("update", update), ("date", date)])
                case .updatesCombined(let updates, let users, let chats, let date, let seqStart, let seq):
                return ("updatesCombined", [("updates", updates), ("users", users), ("chats", chats), ("date", date), ("seqStart", seqStart), ("seq", seq)])
                case .updates(let updates, let users, let chats, let date, let seq):
                return ("updates", [("updates", updates), ("users", users), ("chats", chats), ("date", date), ("seq", seq)])
                case .updateShortSentMessage(let flags, let id, let pts, let ptsCount, let date, let media, let entities):
                return ("updateShortSentMessage", [("flags", flags), ("id", id), ("pts", pts), ("ptsCount", ptsCount), ("date", date), ("media", media), ("entities", entities)])
    }
    }
    
        public static func parse_updatesTooLong(_ reader: BufferReader) -> Updates? {
            return Api.Updates.updatesTooLong
        }
        public static func parse_updateShortMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_10 = reader.readInt32() }
            var _11: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 11) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.Updates.updateShortMessage(flags: _1!, id: _2!, userId: _3!, message: _4!, pts: _5!, ptsCount: _6!, date: _7!, fwdFrom: _8, viaBotId: _9, replyToMsgId: _10, entities: _11)
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortChatMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_10 = reader.readInt32() }
            var _11: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_11 = reader.readInt32() }
            var _12: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.Updates.updateShortChatMessage(flags: _1!, id: _2!, fromId: _3!, chatId: _4!, message: _5!, pts: _6!, ptsCount: _7!, date: _8!, fwdFrom: _9, viaBotId: _10, replyToMsgId: _11, entities: _12)
            }
            else {
                return nil
            }
        }
        public static func parse_updateShort(_ reader: BufferReader) -> Updates? {
            var _1: Api.Update?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Update
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Updates.updateShort(update: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatesCombined(_ reader: BufferReader) -> Updates? {
            var _1: [Api.Update]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Updates.updatesCombined(updates: _1!, users: _2!, chats: _3!, date: _4!, seqStart: _5!, seq: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updates(_ reader: BufferReader) -> Updates? {
            var _1: [Api.Update]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
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
                return Api.Updates.updates(updates: _1!, users: _2!, chats: _3!, date: _4!, seq: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortSentMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _7: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 9) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Updates.updateShortSentMessage(flags: _1!, id: _2!, pts: _3!, ptsCount: _4!, date: _5!, media: _6, entities: _7)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageMedia: TypeConstructorDescription {
        case messageMediaEmpty
        case messageMediaGeo(geo: Api.GeoPoint)
        case messageMediaUnsupported
        case messageMediaWebPage(webpage: Api.WebPage)
        case messageMediaGame(game: Api.Game)
        case messageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String)
        case messageMediaGeoLive(geo: Api.GeoPoint, period: Int32)
        case messageMediaVenue(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case messageMediaPhoto(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?)
        case messageMediaDocument(flags: Int32, document: Api.Document?, ttlSeconds: Int32?)
        case messageMediaContact(phoneNumber: String, firstName: String, lastName: String, vcard: String, userId: Int32)
        case messageMediaPoll(poll: Api.Poll, results: Api.PollResults)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageMediaEmpty:
                    if boxed {
                        buffer.appendInt32(1038967584)
                    }
                    
                    break
                case .messageMediaGeo(let geo):
                    if boxed {
                        buffer.appendInt32(1457575028)
                    }
                    geo.serialize(buffer, true)
                    break
                case .messageMediaUnsupported:
                    if boxed {
                        buffer.appendInt32(-1618676578)
                    }
                    
                    break
                case .messageMediaWebPage(let webpage):
                    if boxed {
                        buffer.appendInt32(-1557277184)
                    }
                    webpage.serialize(buffer, true)
                    break
                case .messageMediaGame(let game):
                    if boxed {
                        buffer.appendInt32(-38694904)
                    }
                    game.serialize(buffer, true)
                    break
                case .messageMediaInvoice(let flags, let title, let description, let photo, let receiptMsgId, let currency, let totalAmount, let startParam):
                    if boxed {
                        buffer.appendInt32(-2074799289)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(receiptMsgId!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    break
                case .messageMediaGeoLive(let geo, let period):
                    if boxed {
                        buffer.appendInt32(2084316681)
                    }
                    geo.serialize(buffer, true)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    break
                case .messageMediaVenue(let geo, let title, let address, let provider, let venueId, let venueType):
                    if boxed {
                        buffer.appendInt32(784356159)
                    }
                    geo.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    break
                case .messageMediaPhoto(let flags, let photo, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(1766936791)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .messageMediaDocument(let flags, let document, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-1666158377)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .messageMediaContact(let phoneNumber, let firstName, let lastName, let vcard, let userId):
                    if boxed {
                        buffer.appendInt32(-873313984)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .messageMediaPoll(let poll, let results):
                    if boxed {
                        buffer.appendInt32(1272375192)
                    }
                    poll.serialize(buffer, true)
                    results.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageMediaEmpty:
                return ("messageMediaEmpty", [])
                case .messageMediaGeo(let geo):
                return ("messageMediaGeo", [("geo", geo)])
                case .messageMediaUnsupported:
                return ("messageMediaUnsupported", [])
                case .messageMediaWebPage(let webpage):
                return ("messageMediaWebPage", [("webpage", webpage)])
                case .messageMediaGame(let game):
                return ("messageMediaGame", [("game", game)])
                case .messageMediaInvoice(let flags, let title, let description, let photo, let receiptMsgId, let currency, let totalAmount, let startParam):
                return ("messageMediaInvoice", [("flags", flags), ("title", title), ("description", description), ("photo", photo), ("receiptMsgId", receiptMsgId), ("currency", currency), ("totalAmount", totalAmount), ("startParam", startParam)])
                case .messageMediaGeoLive(let geo, let period):
                return ("messageMediaGeoLive", [("geo", geo), ("period", period)])
                case .messageMediaVenue(let geo, let title, let address, let provider, let venueId, let venueType):
                return ("messageMediaVenue", [("geo", geo), ("title", title), ("address", address), ("provider", provider), ("venueId", venueId), ("venueType", venueType)])
                case .messageMediaPhoto(let flags, let photo, let ttlSeconds):
                return ("messageMediaPhoto", [("flags", flags), ("photo", photo), ("ttlSeconds", ttlSeconds)])
                case .messageMediaDocument(let flags, let document, let ttlSeconds):
                return ("messageMediaDocument", [("flags", flags), ("document", document), ("ttlSeconds", ttlSeconds)])
                case .messageMediaContact(let phoneNumber, let firstName, let lastName, let vcard, let userId):
                return ("messageMediaContact", [("phoneNumber", phoneNumber), ("firstName", firstName), ("lastName", lastName), ("vcard", vcard), ("userId", userId)])
                case .messageMediaPoll(let poll, let results):
                return ("messageMediaPoll", [("poll", poll), ("results", results)])
    }
    }
    
        public static func parse_messageMediaEmpty(_ reader: BufferReader) -> MessageMedia? {
            return Api.MessageMedia.messageMediaEmpty
        }
        public static func parse_messageMediaGeo(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageMedia.messageMediaGeo(geo: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaUnsupported(_ reader: BufferReader) -> MessageMedia? {
            return Api.MessageMedia.messageMediaUnsupported
        }
        public static func parse_messageMediaWebPage(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageMedia.messageMediaWebPage(webpage: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaGame(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.Game?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Game
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageMedia.messageMediaGame(game: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaInvoice(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.WebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: String?
            _8 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.MessageMedia.messageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, receiptMsgId: _5, currency: _6!, totalAmount: _7!, startParam: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaGeoLive(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaGeoLive(geo: _1!, period: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaVenue(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
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
                return Api.MessageMedia.messageMediaVenue(geo: _1!, title: _2!, address: _3!, provider: _4!, venueId: _5!, venueType: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPhoto(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Photo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaPhoto(flags: _1!, photo: _2, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaDocument(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaDocument(flags: _1!, document: _2, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaContact(_ reader: BufferReader) -> MessageMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageMedia.messageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, vcard: _4!, userId: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPoll(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.Poll?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Poll
            }
            var _2: Api.PollResults?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PollResults
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaPoll(poll: _1!, results: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentSavedCredentials: TypeConstructorDescription {
        case paymentSavedCredentialsCard(id: String, title: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentSavedCredentialsCard(let id, let title):
                    if boxed {
                        buffer.appendInt32(-842892769)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentSavedCredentialsCard(let id, let title):
                return ("paymentSavedCredentialsCard", [("id", id), ("title", title)])
    }
    }
    
        public static func parse_paymentSavedCredentialsCard(_ reader: BufferReader) -> PaymentSavedCredentials? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PaymentSavedCredentials.paymentSavedCredentialsCard(id: _1!, title: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Null: TypeConstructorDescription {
        case null
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .null:
                    if boxed {
                        buffer.appendInt32(1450380236)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .null:
                return ("null", [])
    }
    }
    
        public static func parse_null(_ reader: BufferReader) -> Null? {
            return Api.Null.null
        }
    
    }
    public enum DocumentAttribute: TypeConstructorDescription {
        case documentAttributeImageSize(w: Int32, h: Int32)
        case documentAttributeAnimated
        case documentAttributeSticker(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?)
        case documentAttributeVideo(flags: Int32, duration: Int32, w: Int32, h: Int32)
        case documentAttributeAudio(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?)
        case documentAttributeFilename(fileName: String)
        case documentAttributeHasStickers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .documentAttributeImageSize(let w, let h):
                    if boxed {
                        buffer.appendInt32(1815593308)
                    }
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .documentAttributeAnimated:
                    if boxed {
                        buffer.appendInt32(297109817)
                    }
                    
                    break
                case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                    if boxed {
                        buffer.appendInt32(1662637586)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(alt, buffer: buffer, boxed: false)
                    stickerset.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {maskCoords!.serialize(buffer, true)}
                    break
                case .documentAttributeVideo(let flags, let duration, let w, let h):
                    if boxed {
                        buffer.appendInt32(250621158)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                    if boxed {
                        buffer.appendInt32(-1739392570)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(performer!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(waveform!, buffer: buffer, boxed: false)}
                    break
                case .documentAttributeFilename(let fileName):
                    if boxed {
                        buffer.appendInt32(358154344)
                    }
                    serializeString(fileName, buffer: buffer, boxed: false)
                    break
                case .documentAttributeHasStickers:
                    if boxed {
                        buffer.appendInt32(-1744710921)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .documentAttributeImageSize(let w, let h):
                return ("documentAttributeImageSize", [("w", w), ("h", h)])
                case .documentAttributeAnimated:
                return ("documentAttributeAnimated", [])
                case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                return ("documentAttributeSticker", [("flags", flags), ("alt", alt), ("stickerset", stickerset), ("maskCoords", maskCoords)])
                case .documentAttributeVideo(let flags, let duration, let w, let h):
                return ("documentAttributeVideo", [("flags", flags), ("duration", duration), ("w", w), ("h", h)])
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                return ("documentAttributeAudio", [("flags", flags), ("duration", duration), ("title", title), ("performer", performer), ("waveform", waveform)])
                case .documentAttributeFilename(let fileName):
                return ("documentAttributeFilename", [("fileName", fileName)])
                case .documentAttributeHasStickers:
                return ("documentAttributeHasStickers", [])
    }
    }
    
        public static func parse_documentAttributeImageSize(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.DocumentAttribute.documentAttributeImageSize(w: _1!, h: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeAnimated
        }
        public static func parse_documentAttributeSticker(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _4: Api.MaskCoords?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.DocumentAttribute.documentAttributeSticker(flags: _1!, alt: _2!, stickerset: _3!, maskCoords: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeVideo(_ reader: BufferReader) -> DocumentAttribute? {
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
                return Api.DocumentAttribute.documentAttributeVideo(flags: _1!, duration: _2!, w: _3!, h: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeAudio(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DocumentAttribute.documentAttributeAudio(flags: _1!, duration: _2!, title: _3, performer: _4, waveform: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeFilename(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.DocumentAttribute.documentAttributeFilename(fileName: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeHasStickers(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeHasStickers
        }
    
    }
    public enum BankCardOpenUrl: TypeConstructorDescription {
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
                return ("bankCardOpenUrl", [("url", url), ("name", name)])
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
    public enum ChatPhoto: TypeConstructorDescription {
        case chatPhotoEmpty
        case chatPhoto(photoSmall: Api.FileLocation, photoBig: Api.FileLocation, dcId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(935395612)
                    }
                    
                    break
                case .chatPhoto(let photoSmall, let photoBig, let dcId):
                    if boxed {
                        buffer.appendInt32(1197267925)
                    }
                    photoSmall.serialize(buffer, true)
                    photoBig.serialize(buffer, true)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatPhotoEmpty:
                return ("chatPhotoEmpty", [])
                case .chatPhoto(let photoSmall, let photoBig, let dcId):
                return ("chatPhoto", [("photoSmall", photoSmall), ("photoBig", photoBig), ("dcId", dcId)])
    }
    }
    
        public static func parse_chatPhotoEmpty(_ reader: BufferReader) -> ChatPhoto? {
            return Api.ChatPhoto.chatPhotoEmpty
        }
        public static func parse_chatPhoto(_ reader: BufferReader) -> ChatPhoto? {
            var _1: Api.FileLocation?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.FileLocation
            }
            var _2: Api.FileLocation?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.FileLocation
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatPhoto.chatPhoto(photoSmall: _1!, photoBig: _2!, dcId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PageCaption: TypeConstructorDescription {
        case pageCaption(text: Api.RichText, credit: Api.RichText)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageCaption(let text, let credit):
                    if boxed {
                        buffer.appendInt32(1869903447)
                    }
                    text.serialize(buffer, true)
                    credit.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageCaption(let text, let credit):
                return ("pageCaption", [("text", text), ("credit", credit)])
    }
    }
    
        public static func parse_pageCaption(_ reader: BufferReader) -> PageCaption? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageCaption.pageCaption(text: _1!, credit: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum UrlAuthResult: TypeConstructorDescription {
        case urlAuthResultRequest(flags: Int32, bot: Api.User, domain: String)
        case urlAuthResultAccepted(url: String)
        case urlAuthResultDefault
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .urlAuthResultRequest(let flags, let bot, let domain):
                    if boxed {
                        buffer.appendInt32(-1831650802)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    serializeString(domain, buffer: buffer, boxed: false)
                    break
                case .urlAuthResultAccepted(let url):
                    if boxed {
                        buffer.appendInt32(-1886646706)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .urlAuthResultDefault:
                    if boxed {
                        buffer.appendInt32(-1445536993)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .urlAuthResultRequest(let flags, let bot, let domain):
                return ("urlAuthResultRequest", [("flags", flags), ("bot", bot), ("domain", domain)])
                case .urlAuthResultAccepted(let url):
                return ("urlAuthResultAccepted", [("url", url)])
                case .urlAuthResultDefault:
                return ("urlAuthResultDefault", [])
    }
    }
    
        public static func parse_urlAuthResultRequest(_ reader: BufferReader) -> UrlAuthResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.User
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.UrlAuthResult.urlAuthResultRequest(flags: _1!, bot: _2!, domain: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_urlAuthResultAccepted(_ reader: BufferReader) -> UrlAuthResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.UrlAuthResult.urlAuthResultAccepted(url: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_urlAuthResultDefault(_ reader: BufferReader) -> UrlAuthResult? {
            return Api.UrlAuthResult.urlAuthResultDefault
        }
    
    }
    public enum InputStickerSet: TypeConstructorDescription {
        case inputStickerSetEmpty
        case inputStickerSetID(id: Int64, accessHash: Int64)
        case inputStickerSetShortName(shortName: String)
        case inputStickerSetAnimatedEmoji
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickerSetEmpty:
                    if boxed {
                        buffer.appendInt32(-4838507)
                    }
                    
                    break
                case .inputStickerSetID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1645763991)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2044933984)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetAnimatedEmoji:
                    if boxed {
                        buffer.appendInt32(42402760)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickerSetEmpty:
                return ("inputStickerSetEmpty", [])
                case .inputStickerSetID(let id, let accessHash):
                return ("inputStickerSetID", [("id", id), ("accessHash", accessHash)])
                case .inputStickerSetShortName(let shortName):
                return ("inputStickerSetShortName", [("shortName", shortName)])
                case .inputStickerSetAnimatedEmoji:
                return ("inputStickerSetAnimatedEmoji", [])
    }
    }
    
        public static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmpty
        }
        public static func parse_inputStickerSetID(_ reader: BufferReader) -> InputStickerSet? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputStickerSet.inputStickerSetID(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetShortName(_ reader: BufferReader) -> InputStickerSet? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickerSet.inputStickerSetShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetAnimatedEmoji(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetAnimatedEmoji
        }
    
    }
    public enum BotInfo: TypeConstructorDescription {
        case botInfo(userId: Int32, description: String, commands: [Api.BotCommand])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInfo(let userId, let description, let commands):
                    if boxed {
                        buffer.appendInt32(-1729618630)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(commands.count))
                    for item in commands {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInfo(let userId, let description, let commands):
                return ("botInfo", [("userId", userId), ("description", description), ("commands", commands)])
    }
    }
    
        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.BotCommand]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BotInfo.botInfo(userId: _1!, description: _2!, commands: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum FoundGif: TypeConstructorDescription {
        case foundGif(url: String, thumbUrl: String, contentUrl: String, contentType: String, w: Int32, h: Int32)
        case foundGifCached(url: String, photo: Api.Photo, document: Api.Document)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundGif(let url, let thumbUrl, let contentUrl, let contentType, let w, let h):
                    if boxed {
                        buffer.appendInt32(372165663)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(thumbUrl, buffer: buffer, boxed: false)
                    serializeString(contentUrl, buffer: buffer, boxed: false)
                    serializeString(contentType, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .foundGifCached(let url, let photo, let document):
                    if boxed {
                        buffer.appendInt32(-1670052855)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    document.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .foundGif(let url, let thumbUrl, let contentUrl, let contentType, let w, let h):
                return ("foundGif", [("url", url), ("thumbUrl", thumbUrl), ("contentUrl", contentUrl), ("contentType", contentType), ("w", w), ("h", h)])
                case .foundGifCached(let url, let photo, let document):
                return ("foundGifCached", [("url", url), ("photo", photo), ("document", document)])
    }
    }
    
        public static func parse_foundGif(_ reader: BufferReader) -> FoundGif? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.FoundGif.foundGif(url: _1!, thumbUrl: _2!, contentUrl: _3!, contentType: _4!, w: _5!, h: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_foundGifCached(_ reader: BufferReader) -> FoundGif? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Photo?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.FoundGif.foundGifCached(url: _1!, photo: _2!, document: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum User: TypeConstructorDescription {
        case userEmpty(id: Int32)
        case user(flags: Int32, id: Int32, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: Api.UserProfilePhoto?, status: Api.UserStatus?, botInfoVersion: Int32?, restrictionReason: [Api.RestrictionReason]?, botInlinePlaceholder: String?, langCode: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userEmpty(let id):
                    if boxed {
                        buffer.appendInt32(537022650)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .user(let flags, let id, let accessHash, let firstName, let lastName, let username, let phone, let photo, let status, let botInfoVersion, let restrictionReason, let botInlinePlaceholder, let langCode):
                    if boxed {
                        buffer.appendInt32(-1820043071)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(accessHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(phone!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {status!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt32(botInfoVersion!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 18) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 19) != 0 {serializeString(botInlinePlaceholder!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 22) != 0 {serializeString(langCode!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userEmpty(let id):
                return ("userEmpty", [("id", id)])
                case .user(let flags, let id, let accessHash, let firstName, let lastName, let username, let phone, let photo, let status, let botInfoVersion, let restrictionReason, let botInlinePlaceholder, let langCode):
                return ("user", [("flags", flags), ("id", id), ("accessHash", accessHash), ("firstName", firstName), ("lastName", lastName), ("username", username), ("phone", phone), ("photo", photo), ("status", status), ("botInfoVersion", botInfoVersion), ("restrictionReason", restrictionReason), ("botInlinePlaceholder", botInlinePlaceholder), ("langCode", langCode)])
    }
    }
    
        public static func parse_userEmpty(_ reader: BufferReader) -> User? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.User.userEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_user(_ reader: BufferReader) -> User? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt64() }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = parseString(reader) }
            var _8: Api.UserProfilePhoto?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
            } }
            var _9: Api.UserStatus?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.UserStatus
            } }
            var _10: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_10 = reader.readInt32() }
            var _11: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 18) != 0 {if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            var _12: String?
            if Int(_1!) & Int(1 << 19) != 0 {_12 = parseString(reader) }
            var _13: String?
            if Int(_1!) & Int(1 << 22) != 0 {_13 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 18) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 19) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 22) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.User.user(flags: _1!, id: _2!, accessHash: _3, firstName: _4, lastName: _5, username: _6, phone: _7, photo: _8, status: _9, botInfoVersion: _10, restrictionReason: _11, botInlinePlaceholder: _12, langCode: _13)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Message: TypeConstructorDescription {
        case messageEmpty(id: Int32)
        case messageService(flags: Int32, id: Int32, fromId: Int32?, toId: Api.Peer, replyToMsgId: Int32?, date: Int32, action: Api.MessageAction)
        case message(flags: Int32, id: Int32, fromId: Int32?, toId: Api.Peer, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int32?, replyToMsgId: Int32?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, restrictionReason: [Api.RestrictionReason]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-2082087340)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .messageService(let flags, let id, let fromId, let toId, let replyToMsgId, let date, let action):
                    if boxed {
                        buffer.appendInt32(-1642487306)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt32(fromId!, buffer: buffer, boxed: false)}
                    toId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
                case .message(let flags, let id, let fromId, let toId, let fwdFrom, let viaBotId, let replyToMsgId, let date, let message, let media, let replyMarkup, let entities, let views, let editDate, let postAuthor, let groupedId, let restrictionReason):
                    if boxed {
                        buffer.appendInt32(1160515173)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt32(fromId!, buffer: buffer, boxed: false)}
                    toId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(views!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(editDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 16) != 0 {serializeString(postAuthor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt64(groupedId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 22) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageEmpty(let id):
                return ("messageEmpty", [("id", id)])
                case .messageService(let flags, let id, let fromId, let toId, let replyToMsgId, let date, let action):
                return ("messageService", [("flags", flags), ("id", id), ("fromId", fromId), ("toId", toId), ("replyToMsgId", replyToMsgId), ("date", date), ("action", action)])
                case .message(let flags, let id, let fromId, let toId, let fwdFrom, let viaBotId, let replyToMsgId, let date, let message, let media, let replyMarkup, let entities, let views, let editDate, let postAuthor, let groupedId, let restrictionReason):
                return ("message", [("flags", flags), ("id", id), ("fromId", fromId), ("toId", toId), ("fwdFrom", fwdFrom), ("viaBotId", viaBotId), ("replyToMsgId", replyToMsgId), ("date", date), ("message", message), ("media", media), ("replyMarkup", replyMarkup), ("entities", entities), ("views", views), ("editDate", editDate), ("postAuthor", postAuthor), ("groupedId", groupedId), ("restrictionReason", restrictionReason)])
    }
    }
    
        public static func parse_messageEmpty(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Message.messageEmpty(id: _1!)
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
            var _3: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {_3 = reader.readInt32() }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.MessageAction?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.MessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Message.messageService(flags: _1!, id: _2!, fromId: _3, toId: _4!, replyToMsgId: _5, date: _6!, action: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_message(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {_3 = reader.readInt32() }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _6: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = reader.readInt32() }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            var _10: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _11: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            var _12: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _13: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {_14 = reader.readInt32() }
            var _15: String?
            if Int(_1!) & Int(1 << 16) != 0 {_15 = parseString(reader) }
            var _16: Int64?
            if Int(_1!) & Int(1 << 17) != 0 {_16 = reader.readInt64() }
            var _17: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 22) != 0 {if let _ = reader.readInt32() {
                _17 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 11) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 9) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 6) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 10) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 15) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 16) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 17) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 22) == 0) || _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.Message.message(flags: _1!, id: _2!, fromId: _3, toId: _4!, fwdFrom: _5, viaBotId: _6, replyToMsgId: _7, date: _8!, message: _9!, media: _10, replyMarkup: _11, entities: _12, views: _13, editDate: _14, postAuthor: _15, groupedId: _16, restrictionReason: _17)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputFileLocation: TypeConstructorDescription {
        case inputEncryptedFileLocation(id: Int64, accessHash: Int64)
        case inputSecureFileLocation(id: Int64, accessHash: Int64)
        case inputFileLocation(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer)
        case inputPhotoFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputDocumentFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputPeerPhotoFileLocation(flags: Int32, peer: Api.InputPeer, volumeId: Int64, localId: Int32)
        case inputStickerSetThumb(stickerset: Api.InputStickerSet, volumeId: Int64, localId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedFileLocation(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-182231723)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputSecureFileLocation(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-876089816)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputFileLocation(let volumeId, let localId, let secret, let fileReference):
                    if boxed {
                        buffer.appendInt32(-539317279)
                    }
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
                case .inputPhotoFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                    if boxed {
                        buffer.appendInt32(1075322878)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeString(thumbSize, buffer: buffer, boxed: false)
                    break
                case .inputDocumentFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                    if boxed {
                        buffer.appendInt32(-1160743548)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeString(thumbSize, buffer: buffer, boxed: false)
                    break
                case .inputPeerPhotoFileLocation(let flags, let peer, let volumeId, let localId):
                    if boxed {
                        buffer.appendInt32(668375447)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetThumb(let stickerset, let volumeId, let localId):
                    if boxed {
                        buffer.appendInt32(230353641)
                    }
                    stickerset.serialize(buffer, true)
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedFileLocation(let id, let accessHash):
                return ("inputEncryptedFileLocation", [("id", id), ("accessHash", accessHash)])
                case .inputSecureFileLocation(let id, let accessHash):
                return ("inputSecureFileLocation", [("id", id), ("accessHash", accessHash)])
                case .inputFileLocation(let volumeId, let localId, let secret, let fileReference):
                return ("inputFileLocation", [("volumeId", volumeId), ("localId", localId), ("secret", secret), ("fileReference", fileReference)])
                case .inputPhotoFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                return ("inputPhotoFileLocation", [("id", id), ("accessHash", accessHash), ("fileReference", fileReference), ("thumbSize", thumbSize)])
                case .inputDocumentFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                return ("inputDocumentFileLocation", [("id", id), ("accessHash", accessHash), ("fileReference", fileReference), ("thumbSize", thumbSize)])
                case .inputPeerPhotoFileLocation(let flags, let peer, let volumeId, let localId):
                return ("inputPeerPhotoFileLocation", [("flags", flags), ("peer", peer), ("volumeId", volumeId), ("localId", localId)])
                case .inputStickerSetThumb(let stickerset, let volumeId, let localId):
                return ("inputStickerSetThumb", [("stickerset", stickerset), ("volumeId", volumeId), ("localId", localId)])
    }
    }
    
        public static func parse_inputEncryptedFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputEncryptedFileLocation(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputSecureFileLocation(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputFileLocation(volumeId: _1!, localId: _2!, secret: _3!, fileReference: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputPhotoFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputDocumentFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputDocumentFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputPeerPhotoFileLocation(flags: _1!, peer: _2!, volumeId: _3!, localId: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetThumb(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFileLocation.inputStickerSetThumb(stickerset: _1!, volumeId: _2!, localId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum GeoPoint: TypeConstructorDescription {
        case geoPointEmpty
        case geoPoint(long: Double, lat: Double, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .geoPointEmpty:
                    if boxed {
                        buffer.appendInt32(286776671)
                    }
                    
                    break
                case .geoPoint(let long, let lat, let accessHash):
                    if boxed {
                        buffer.appendInt32(43446532)
                    }
                    serializeDouble(long, buffer: buffer, boxed: false)
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .geoPointEmpty:
                return ("geoPointEmpty", [])
                case .geoPoint(let long, let lat, let accessHash):
                return ("geoPoint", [("long", long), ("lat", lat), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            return Api.GeoPoint.geoPointEmpty
        }
        public static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GeoPoint.geoPoint(long: _1!, lat: _2!, accessHash: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputPhoneCall: TypeConstructorDescription {
        case inputPhoneCall(id: Int64, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoneCall(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(506920429)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoneCall(let id, let accessHash):
                return ("inputPhoneCall", [("id", id), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputPhoneCall(_ reader: BufferReader) -> InputPhoneCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPhoneCall.inputPhoneCall(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ReceivedNotifyMessage: TypeConstructorDescription {
        case receivedNotifyMessage(id: Int32, flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .receivedNotifyMessage(let id, let flags):
                    if boxed {
                        buffer.appendInt32(-1551583367)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .receivedNotifyMessage(let id, let flags):
                return ("receivedNotifyMessage", [("id", id), ("flags", flags)])
    }
    }
    
        public static func parse_receivedNotifyMessage(_ reader: BufferReader) -> ReceivedNotifyMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReceivedNotifyMessage.receivedNotifyMessage(id: _1!, flags: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatParticipants: TypeConstructorDescription {
        case chatParticipantsForbidden(flags: Int32, chatId: Int32, selfParticipant: Api.ChatParticipant?)
        case chatParticipants(chatId: Int32, participants: [Api.ChatParticipant], version: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatParticipantsForbidden(let flags, let chatId, let selfParticipant):
                    if boxed {
                        buffer.appendInt32(-57668565)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {selfParticipant!.serialize(buffer, true)}
                    break
                case .chatParticipants(let chatId, let participants, let version):
                    if boxed {
                        buffer.appendInt32(1061556205)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatParticipantsForbidden(let flags, let chatId, let selfParticipant):
                return ("chatParticipantsForbidden", [("flags", flags), ("chatId", chatId), ("selfParticipant", selfParticipant)])
                case .chatParticipants(let chatId, let participants, let version):
                return ("chatParticipants", [("chatId", chatId), ("participants", participants), ("version", version)])
    }
    }
    
        public static func parse_chatParticipantsForbidden(_ reader: BufferReader) -> ChatParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatParticipants.chatParticipantsForbidden(flags: _1!, chatId: _2!, selfParticipant: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipants(_ reader: BufferReader) -> ChatParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ChatParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChatParticipant.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatParticipants.chatParticipants(chatId: _1!, participants: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputPaymentCredentials: TypeConstructorDescription {
        case inputPaymentCredentialsSaved(id: String, tmpPassword: Buffer)
        case inputPaymentCredentials(flags: Int32, data: Api.DataJSON)
        case inputPaymentCredentialsApplePay(paymentData: Api.DataJSON)
        case inputPaymentCredentialsAndroidPay(paymentToken: Api.DataJSON, googleTransactionId: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPaymentCredentialsSaved(let id, let tmpPassword):
                    if boxed {
                        buffer.appendInt32(-1056001329)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeBytes(tmpPassword, buffer: buffer, boxed: false)
                    break
                case .inputPaymentCredentials(let flags, let data):
                    if boxed {
                        buffer.appendInt32(873977640)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsApplePay(let paymentData):
                    if boxed {
                        buffer.appendInt32(178373535)
                    }
                    paymentData.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsAndroidPay(let paymentToken, let googleTransactionId):
                    if boxed {
                        buffer.appendInt32(-905587442)
                    }
                    paymentToken.serialize(buffer, true)
                    serializeString(googleTransactionId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPaymentCredentialsSaved(let id, let tmpPassword):
                return ("inputPaymentCredentialsSaved", [("id", id), ("tmpPassword", tmpPassword)])
                case .inputPaymentCredentials(let flags, let data):
                return ("inputPaymentCredentials", [("flags", flags), ("data", data)])
                case .inputPaymentCredentialsApplePay(let paymentData):
                return ("inputPaymentCredentialsApplePay", [("paymentData", paymentData)])
                case .inputPaymentCredentialsAndroidPay(let paymentToken, let googleTransactionId):
                return ("inputPaymentCredentialsAndroidPay", [("paymentToken", paymentToken), ("googleTransactionId", googleTransactionId)])
    }
    }
    
        public static func parse_inputPaymentCredentialsSaved(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsSaved(id: _1!, tmpPassword: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentials(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentials(flags: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsApplePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsApplePay(paymentData: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsAndroidPay(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsAndroidPay(paymentToken: _1!, googleTransactionId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ShippingOption: TypeConstructorDescription {
        case shippingOption(id: String, title: String, prices: [Api.LabeledPrice])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .shippingOption(let id, let title, let prices):
                    if boxed {
                        buffer.appendInt32(-1239335713)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .shippingOption(let id, let title, let prices):
                return ("shippingOption", [("id", id), ("title", title), ("prices", prices)])
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
                return Api.ShippingOption.shippingOption(id: _1!, title: _2!, prices: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputSecureFile: TypeConstructorDescription {
        case inputSecureFileUploaded(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer)
        case inputSecureFile(id: Int64, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSecureFileUploaded(let id, let parts, let md5Checksum, let fileHash, let secret):
                    if boxed {
                        buffer.appendInt32(859091184)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
                case .inputSecureFile(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1399317950)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSecureFileUploaded(let id, let parts, let md5Checksum, let fileHash, let secret):
                return ("inputSecureFileUploaded", [("id", id), ("parts", parts), ("md5Checksum", md5Checksum), ("fileHash", fileHash), ("secret", secret)])
                case .inputSecureFile(let id, let accessHash):
                return ("inputSecureFile", [("id", id), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputSecureFileUploaded(_ reader: BufferReader) -> InputSecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSecureFile.inputSecureFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, fileHash: _4!, secret: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFile(_ reader: BufferReader) -> InputSecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputSecureFile.inputSecureFile(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PostAddress: TypeConstructorDescription {
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
                return ("postAddress", [("streetLine1", streetLine1), ("streetLine2", streetLine2), ("city", city), ("state", state), ("countryIso2", countryIso2), ("postCode", postCode)])
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
    public enum InputFolderPeer: TypeConstructorDescription {
        case inputFolderPeer(peer: Api.InputPeer, folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputFolderPeer(let peer, let folderId):
                    if boxed {
                        buffer.appendInt32(-70073706)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputFolderPeer(let peer, let folderId):
                return ("inputFolderPeer", [("peer", peer), ("folderId", folderId)])
    }
    }
    
        public static func parse_inputFolderPeer(_ reader: BufferReader) -> InputFolderPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFolderPeer.inputFolderPeer(peer: _1!, folderId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum DataJSON: TypeConstructorDescription {
        case dataJSON(data: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dataJSON(let data):
                    if boxed {
                        buffer.appendInt32(2104790276)
                    }
                    serializeString(data, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dataJSON(let data):
                return ("dataJSON", [("data", data)])
    }
    }
    
        public static func parse_dataJSON(_ reader: BufferReader) -> DataJSON? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.DataJSON.dataJSON(data: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputWallPaper: TypeConstructorDescription {
        case inputWallPaper(id: Int64, accessHash: Int64)
        case inputWallPaperSlug(slug: String)
        case inputWallPaperNoFile
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWallPaper(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-433014407)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputWallPaperSlug(let slug):
                    if boxed {
                        buffer.appendInt32(1913199744)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
                case .inputWallPaperNoFile:
                    if boxed {
                        buffer.appendInt32(-2077770836)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWallPaper(let id, let accessHash):
                return ("inputWallPaper", [("id", id), ("accessHash", accessHash)])
                case .inputWallPaperSlug(let slug):
                return ("inputWallPaperSlug", [("slug", slug)])
                case .inputWallPaperNoFile:
                return ("inputWallPaperNoFile", [])
    }
    }
    
        public static func parse_inputWallPaper(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWallPaper.inputWallPaper(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperSlug(_ reader: BufferReader) -> InputWallPaper? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperNoFile(_ reader: BufferReader) -> InputWallPaper? {
            return Api.InputWallPaper.inputWallPaperNoFile
        }
    
    }
    public enum InputThemeSettings: TypeConstructorDescription {
        case inputThemeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, messageTopColor: Int32?, messageBottomColor: Int32?, wallpaper: Api.InputWallPaper?, wallpaperSettings: Api.WallPaperSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputThemeSettings(let flags, let baseTheme, let accentColor, let messageTopColor, let messageBottomColor, let wallpaper, let wallpaperSettings):
                    if boxed {
                        buffer.appendInt32(-1118798639)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    baseTheme.serialize(buffer, true)
                    serializeInt32(accentColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(messageTopColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(messageBottomColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaper!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaperSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputThemeSettings(let flags, let baseTheme, let accentColor, let messageTopColor, let messageBottomColor, let wallpaper, let wallpaperSettings):
                return ("inputThemeSettings", [("flags", flags), ("baseTheme", baseTheme), ("accentColor", accentColor), ("messageTopColor", messageTopColor), ("messageBottomColor", messageBottomColor), ("wallpaper", wallpaper), ("wallpaperSettings", wallpaperSettings)])
    }
    }
    
        public static func parse_inputThemeSettings(_ reader: BufferReader) -> InputThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Api.InputWallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputWallPaper
            } }
            var _7: Api.WallPaperSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputThemeSettings.inputThemeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, messageTopColor: _4, messageBottomColor: _5, wallpaper: _6, wallpaperSettings: _7)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputStickeredMedia: TypeConstructorDescription {
        case inputStickeredMediaPhoto(id: Api.InputPhoto)
        case inputStickeredMediaDocument(id: Api.InputDocument)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickeredMediaPhoto(let id):
                    if boxed {
                        buffer.appendInt32(1251549527)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputStickeredMediaDocument(let id):
                    if boxed {
                        buffer.appendInt32(70813275)
                    }
                    id.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickeredMediaPhoto(let id):
                return ("inputStickeredMediaPhoto", [("id", id)])
                case .inputStickeredMediaDocument(let id):
                return ("inputStickeredMediaDocument", [("id", id)])
    }
    }
    
        public static func parse_inputStickeredMediaPhoto(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaPhoto(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaDocument(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WebPageAttribute: TypeConstructorDescription {
        case webPageAttributeTheme(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webPageAttributeTheme(let flags, let documents, let settings):
                    if boxed {
                        buffer.appendInt32(1421174295)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents!.count))
                    for item in documents! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {settings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webPageAttributeTheme(let flags, let documents, let settings):
                return ("webPageAttributeTheme", [("flags", flags), ("documents", documents), ("settings", settings)])
    }
    }
    
        public static func parse_webPageAttributeTheme(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            } }
            var _3: Api.ThemeSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ThemeSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebPageAttribute.webPageAttributeTheme(flags: _1!, documents: _2, settings: _3)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PhoneCallDiscardReason: TypeConstructorDescription {
        case phoneCallDiscardReasonMissed
        case phoneCallDiscardReasonDisconnect
        case phoneCallDiscardReasonHangup
        case phoneCallDiscardReasonBusy
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCallDiscardReasonMissed:
                    if boxed {
                        buffer.appendInt32(-2048646399)
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
                case .phoneCallDiscardReasonBusy:
                    if boxed {
                        buffer.appendInt32(-84416311)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCallDiscardReasonMissed:
                return ("phoneCallDiscardReasonMissed", [])
                case .phoneCallDiscardReasonDisconnect:
                return ("phoneCallDiscardReasonDisconnect", [])
                case .phoneCallDiscardReasonHangup:
                return ("phoneCallDiscardReasonHangup", [])
                case .phoneCallDiscardReasonBusy:
                return ("phoneCallDiscardReasonBusy", [])
    }
    }
    
        public static func parse_phoneCallDiscardReasonMissed(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonMissed
        }
        public static func parse_phoneCallDiscardReasonDisconnect(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonDisconnect
        }
        public static func parse_phoneCallDiscardReasonHangup(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonHangup
        }
        public static func parse_phoneCallDiscardReasonBusy(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonBusy
        }
    
    }
    public enum NearestDc: TypeConstructorDescription {
        case nearestDc(country: String, thisDc: Int32, nearestDc: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .nearestDc(let country, let thisDc, let nearestDc):
                    if boxed {
                        buffer.appendInt32(-1910892683)
                    }
                    serializeString(country, buffer: buffer, boxed: false)
                    serializeInt32(thisDc, buffer: buffer, boxed: false)
                    serializeInt32(nearestDc, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .nearestDc(let country, let thisDc, let nearestDc):
                return ("nearestDc", [("country", country), ("thisDc", thisDc), ("nearestDc", nearestDc)])
    }
    }
    
        public static func parse_nearestDc(_ reader: BufferReader) -> NearestDc? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.NearestDc.nearestDc(country: _1!, thisDc: _2!, nearestDc: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum JSONObjectValue: TypeConstructorDescription {
        case jsonObjectValue(key: String, value: Api.JSONValue)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .jsonObjectValue(let key, let value):
                    if boxed {
                        buffer.appendInt32(-1059185703)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    value.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .jsonObjectValue(let key, let value):
                return ("jsonObjectValue", [("key", key), ("value", value)])
    }
    }
    
        public static func parse_jsonObjectValue(_ reader: BufferReader) -> JSONObjectValue? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.JSONValue?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.JSONObjectValue.jsonObjectValue(key: _1!, value: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputWebDocument: TypeConstructorDescription {
        case inputWebDocument(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWebDocument(let url, let size, let mimeType, let attributes):
                    if boxed {
                        buffer.appendInt32(-1678949555)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWebDocument(let url, let size, let mimeType, let attributes):
                return ("inputWebDocument", [("url", url), ("size", size), ("mimeType", mimeType), ("attributes", attributes)])
    }
    }
    
        public static func parse_inputWebDocument(_ reader: BufferReader) -> InputWebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWebDocument.inputWebDocument(url: _1!, size: _2!, mimeType: _3!, attributes: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelAdminLogEvent: TypeConstructorDescription {
        case channelAdminLogEvent(id: Int64, date: Int32, userId: Int32, action: Api.ChannelAdminLogEventAction)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEvent(let id, let date, let userId, let action):
                    if boxed {
                        buffer.appendInt32(995769920)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEvent(let id, let date, let userId, let action):
                return ("channelAdminLogEvent", [("id", id), ("date", date), ("userId", userId), ("action", action)])
    }
    }
    
        public static func parse_channelAdminLogEvent(_ reader: BufferReader) -> ChannelAdminLogEvent? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.ChannelAdminLogEventAction?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChannelAdminLogEventAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChannelAdminLogEvent.channelAdminLogEvent(id: _1!, date: _2!, userId: _3!, action: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Bool: TypeConstructorDescription {
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
    public enum LangPackString: TypeConstructorDescription {
        case langPackString(key: String, value: String)
        case langPackStringPluralized(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String)
        case langPackStringDeleted(key: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .langPackString(let key, let value):
                    if boxed {
                        buffer.appendInt32(-892239370)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    serializeString(value, buffer: buffer, boxed: false)
                    break
                case .langPackStringPluralized(let flags, let key, let zeroValue, let oneValue, let twoValue, let fewValue, let manyValue, let otherValue):
                    if boxed {
                        buffer.appendInt32(1816636575)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(zeroValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(oneValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(twoValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(fewValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(manyValue!, buffer: buffer, boxed: false)}
                    serializeString(otherValue, buffer: buffer, boxed: false)
                    break
                case .langPackStringDeleted(let key):
                    if boxed {
                        buffer.appendInt32(695856818)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .langPackString(let key, let value):
                return ("langPackString", [("key", key), ("value", value)])
                case .langPackStringPluralized(let flags, let key, let zeroValue, let oneValue, let twoValue, let fewValue, let manyValue, let otherValue):
                return ("langPackStringPluralized", [("flags", flags), ("key", key), ("zeroValue", zeroValue), ("oneValue", oneValue), ("twoValue", twoValue), ("fewValue", fewValue), ("manyValue", manyValue), ("otherValue", otherValue)])
                case .langPackStringDeleted(let key):
                return ("langPackStringDeleted", [("key", key)])
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
                return Api.LangPackString.langPackString(key: _1!, value: _2!)
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
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = parseString(reader) }
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
                return Api.LangPackString.langPackStringPluralized(flags: _1!, key: _2!, zeroValue: _3, oneValue: _4, twoValue: _5, fewValue: _6, manyValue: _7, otherValue: _8!)
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
                return Api.LangPackString.langPackStringDeleted(key: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputWebFileLocation: TypeConstructorDescription {
        case inputWebFileLocation(url: String, accessHash: Int64)
        case inputWebFileGeoMessageLocation(peer: Api.InputPeer, msgId: Int32, w: Int32, h: Int32, zoom: Int32, scale: Int32)
        case inputWebFileGeoPointLocation(geoPoint: Api.InputGeoPoint, accessHash: Int64, w: Int32, h: Int32, zoom: Int32, scale: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWebFileLocation(let url, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1036396922)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputWebFileGeoMessageLocation(let peer, let msgId, let w, let h, let zoom, let scale):
                    if boxed {
                        buffer.appendInt32(1430205163)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(zoom, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    break
                case .inputWebFileGeoPointLocation(let geoPoint, let accessHash, let w, let h, let zoom, let scale):
                    if boxed {
                        buffer.appendInt32(-1625153079)
                    }
                    geoPoint.serialize(buffer, true)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(zoom, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWebFileLocation(let url, let accessHash):
                return ("inputWebFileLocation", [("url", url), ("accessHash", accessHash)])
                case .inputWebFileGeoMessageLocation(let peer, let msgId, let w, let h, let zoom, let scale):
                return ("inputWebFileGeoMessageLocation", [("peer", peer), ("msgId", msgId), ("w", w), ("h", h), ("zoom", zoom), ("scale", scale)])
                case .inputWebFileGeoPointLocation(let geoPoint, let accessHash, let w, let h, let zoom, let scale):
                return ("inputWebFileGeoPointLocation", [("geoPoint", geoPoint), ("accessHash", accessHash), ("w", w), ("h", h), ("zoom", zoom), ("scale", scale)])
    }
    }
    
        public static func parse_inputWebFileLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWebFileLocation.inputWebFileLocation(url: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileGeoMessageLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputWebFileLocation.inputWebFileGeoMessageLocation(peer: _1!, msgId: _2!, w: _3!, h: _4!, zoom: _5!, scale: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileGeoPointLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputWebFileLocation.inputWebFileGeoPointLocation(geoPoint: _1!, accessHash: _2!, w: _3!, h: _4!, zoom: _5!, scale: _6!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageFwdHeader: TypeConstructorDescription {
        case messageFwdHeader(flags: Int32, fromId: Int32?, fromName: String?, date: Int32, channelId: Int32?, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageFwdHeader(let flags, let fromId, let fromName, let date, let channelId, let channelPost, let postAuthor, let savedFromPeer, let savedFromMsgId):
                    if boxed {
                        buffer.appendInt32(-332168592)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(fromId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(fromName!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(channelId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(channelPost!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(postAuthor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {savedFromPeer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(savedFromMsgId!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageFwdHeader(let flags, let fromId, let fromName, let date, let channelId, let channelPost, let postAuthor, let savedFromPeer, let savedFromMsgId):
                return ("messageFwdHeader", [("flags", flags), ("fromId", fromId), ("fromName", fromName), ("date", date), ("channelId", channelId), ("channelPost", channelPost), ("postAuthor", postAuthor), ("savedFromPeer", savedFromPeer), ("savedFromMsgId", savedFromMsgId)])
    }
    }
    
        public static func parse_messageFwdHeader(_ reader: BufferReader) -> MessageFwdHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: String?
            if Int(_1!) & Int(1 << 5) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = parseString(reader) }
            var _8: Api.Peer?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_9 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 5) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.MessageFwdHeader.messageFwdHeader(flags: _1!, fromId: _2, fromName: _3, date: _4!, channelId: _5, channelPost: _6, postAuthor: _7, savedFromPeer: _8, savedFromMsgId: _9)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BaseTheme: TypeConstructorDescription {
        case baseThemeClassic
        case baseThemeDay
        case baseThemeNight
        case baseThemeTinted
        case baseThemeArctic
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .baseThemeArctic:
                    if boxed {
                        buffer.appendInt32(1527845466)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .baseThemeClassic:
                return ("baseThemeClassic", [])
                case .baseThemeDay:
                return ("baseThemeDay", [])
                case .baseThemeNight:
                return ("baseThemeNight", [])
                case .baseThemeTinted:
                return ("baseThemeTinted", [])
                case .baseThemeArctic:
                return ("baseThemeArctic", [])
    }
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
        public static func parse_baseThemeArctic(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeArctic
        }
    
    }
    public enum MessagesFilter: TypeConstructorDescription {
        case inputMessagesFilterEmpty
        case inputMessagesFilterPhotos
        case inputMessagesFilterVideo
        case inputMessagesFilterPhotoVideo
        case inputMessagesFilterPhotoVideoDocuments
        case inputMessagesFilterDocument
        case inputMessagesFilterUrl
        case inputMessagesFilterGif
        case inputMessagesFilterVoice
        case inputMessagesFilterMusic
        case inputMessagesFilterChatPhotos
        case inputMessagesFilterPhoneCalls(flags: Int32)
        case inputMessagesFilterRoundVoice
        case inputMessagesFilterRoundVideo
        case inputMessagesFilterMyMentions
        case inputMessagesFilterMyMentionsUnread
        case inputMessagesFilterGeo
        case inputMessagesFilterContacts
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMessagesFilterEmpty:
                    if boxed {
                        buffer.appendInt32(1474492012)
                    }
                    
                    break
                case .inputMessagesFilterPhotos:
                    if boxed {
                        buffer.appendInt32(-1777752804)
                    }
                    
                    break
                case .inputMessagesFilterVideo:
                    if boxed {
                        buffer.appendInt32(-1614803355)
                    }
                    
                    break
                case .inputMessagesFilterPhotoVideo:
                    if boxed {
                        buffer.appendInt32(1458172132)
                    }
                    
                    break
                case .inputMessagesFilterPhotoVideoDocuments:
                    if boxed {
                        buffer.appendInt32(-648121413)
                    }
                    
                    break
                case .inputMessagesFilterDocument:
                    if boxed {
                        buffer.appendInt32(-1629621880)
                    }
                    
                    break
                case .inputMessagesFilterUrl:
                    if boxed {
                        buffer.appendInt32(2129714567)
                    }
                    
                    break
                case .inputMessagesFilterGif:
                    if boxed {
                        buffer.appendInt32(-3644025)
                    }
                    
                    break
                case .inputMessagesFilterVoice:
                    if boxed {
                        buffer.appendInt32(1358283666)
                    }
                    
                    break
                case .inputMessagesFilterMusic:
                    if boxed {
                        buffer.appendInt32(928101534)
                    }
                    
                    break
                case .inputMessagesFilterChatPhotos:
                    if boxed {
                        buffer.appendInt32(975236280)
                    }
                    
                    break
                case .inputMessagesFilterPhoneCalls(let flags):
                    if boxed {
                        buffer.appendInt32(-2134272152)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .inputMessagesFilterRoundVoice:
                    if boxed {
                        buffer.appendInt32(2054952868)
                    }
                    
                    break
                case .inputMessagesFilterRoundVideo:
                    if boxed {
                        buffer.appendInt32(-1253451181)
                    }
                    
                    break
                case .inputMessagesFilterMyMentions:
                    if boxed {
                        buffer.appendInt32(-1040652646)
                    }
                    
                    break
                case .inputMessagesFilterMyMentionsUnread:
                    if boxed {
                        buffer.appendInt32(1187706024)
                    }
                    
                    break
                case .inputMessagesFilterGeo:
                    if boxed {
                        buffer.appendInt32(-419271411)
                    }
                    
                    break
                case .inputMessagesFilterContacts:
                    if boxed {
                        buffer.appendInt32(-530392189)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMessagesFilterEmpty:
                return ("inputMessagesFilterEmpty", [])
                case .inputMessagesFilterPhotos:
                return ("inputMessagesFilterPhotos", [])
                case .inputMessagesFilterVideo:
                return ("inputMessagesFilterVideo", [])
                case .inputMessagesFilterPhotoVideo:
                return ("inputMessagesFilterPhotoVideo", [])
                case .inputMessagesFilterPhotoVideoDocuments:
                return ("inputMessagesFilterPhotoVideoDocuments", [])
                case .inputMessagesFilterDocument:
                return ("inputMessagesFilterDocument", [])
                case .inputMessagesFilterUrl:
                return ("inputMessagesFilterUrl", [])
                case .inputMessagesFilterGif:
                return ("inputMessagesFilterGif", [])
                case .inputMessagesFilterVoice:
                return ("inputMessagesFilterVoice", [])
                case .inputMessagesFilterMusic:
                return ("inputMessagesFilterMusic", [])
                case .inputMessagesFilterChatPhotos:
                return ("inputMessagesFilterChatPhotos", [])
                case .inputMessagesFilterPhoneCalls(let flags):
                return ("inputMessagesFilterPhoneCalls", [("flags", flags)])
                case .inputMessagesFilterRoundVoice:
                return ("inputMessagesFilterRoundVoice", [])
                case .inputMessagesFilterRoundVideo:
                return ("inputMessagesFilterRoundVideo", [])
                case .inputMessagesFilterMyMentions:
                return ("inputMessagesFilterMyMentions", [])
                case .inputMessagesFilterMyMentionsUnread:
                return ("inputMessagesFilterMyMentionsUnread", [])
                case .inputMessagesFilterGeo:
                return ("inputMessagesFilterGeo", [])
                case .inputMessagesFilterContacts:
                return ("inputMessagesFilterContacts", [])
    }
    }
    
        public static func parse_inputMessagesFilterEmpty(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterEmpty
        }
        public static func parse_inputMessagesFilterPhotos(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterPhotos
        }
        public static func parse_inputMessagesFilterVideo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterVideo
        }
        public static func parse_inputMessagesFilterPhotoVideo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterPhotoVideo
        }
        public static func parse_inputMessagesFilterPhotoVideoDocuments(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterPhotoVideoDocuments
        }
        public static func parse_inputMessagesFilterDocument(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterDocument
        }
        public static func parse_inputMessagesFilterUrl(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterUrl
        }
        public static func parse_inputMessagesFilterGif(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterGif
        }
        public static func parse_inputMessagesFilterVoice(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterVoice
        }
        public static func parse_inputMessagesFilterMusic(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterMusic
        }
        public static func parse_inputMessagesFilterChatPhotos(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterChatPhotos
        }
        public static func parse_inputMessagesFilterPhoneCalls(_ reader: BufferReader) -> MessagesFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessagesFilter.inputMessagesFilterPhoneCalls(flags: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessagesFilterRoundVoice(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterRoundVoice
        }
        public static func parse_inputMessagesFilterRoundVideo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterRoundVideo
        }
        public static func parse_inputMessagesFilterMyMentions(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterMyMentions
        }
        public static func parse_inputMessagesFilterMyMentionsUnread(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterMyMentionsUnread
        }
        public static func parse_inputMessagesFilterGeo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterGeo
        }
        public static func parse_inputMessagesFilterContacts(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterContacts
        }
    
    }
    public enum EmojiKeyword: TypeConstructorDescription {
        case emojiKeyword(keyword: String, emoticons: [String])
        case emojiKeywordDeleted(keyword: String, emoticons: [String])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiKeyword(let keyword, let emoticons):
                    if boxed {
                        buffer.appendInt32(-709641735)
                    }
                    serializeString(keyword, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .emojiKeywordDeleted(let keyword, let emoticons):
                    if boxed {
                        buffer.appendInt32(594408994)
                    }
                    serializeString(keyword, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiKeyword(let keyword, let emoticons):
                return ("emojiKeyword", [("keyword", keyword), ("emoticons", emoticons)])
                case .emojiKeywordDeleted(let keyword, let emoticons):
                return ("emojiKeywordDeleted", [("keyword", keyword), ("emoticons", emoticons)])
    }
    }
    
        public static func parse_emojiKeyword(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeyword(keyword: _1!, emoticons: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiKeywordDeleted(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeywordDeleted(keyword: _1!, emoticons: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BotInlineMessage: TypeConstructorDescription {
        case botInlineMessageText(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaGeo(flags: Int32, geo: Api.GeoPoint, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaVenue(flags: Int32, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInlineMessageText(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1937807902)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaGeo(let flags, let geo, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(982505656)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1984755728)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaVenue(let flags, let geo, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1970903652)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geo.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(416402882)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInlineMessageText(let flags, let message, let entities, let replyMarkup):
                return ("botInlineMessageText", [("flags", flags), ("message", message), ("entities", entities), ("replyMarkup", replyMarkup)])
                case .botInlineMessageMediaGeo(let flags, let geo, let replyMarkup):
                return ("botInlineMessageMediaGeo", [("flags", flags), ("geo", geo), ("replyMarkup", replyMarkup)])
                case .botInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                return ("botInlineMessageMediaAuto", [("flags", flags), ("message", message), ("entities", entities), ("replyMarkup", replyMarkup)])
                case .botInlineMessageMediaVenue(let flags, let geo, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                return ("botInlineMessageMediaVenue", [("flags", flags), ("geo", geo), ("title", title), ("address", address), ("provider", provider), ("venueId", venueId), ("venueType", venueType), ("replyMarkup", replyMarkup)])
                case .botInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                return ("botInlineMessageMediaContact", [("flags", flags), ("phoneNumber", phoneNumber), ("firstName", firstName), ("lastName", lastName), ("vcard", vcard), ("replyMarkup", replyMarkup)])
    }
    }
    
        public static func parse_botInlineMessageText(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BotInlineMessage.botInlineMessageText(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaGeo(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _3: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BotInlineMessage.botInlineMessageMediaGeo(flags: _1!, geo: _2!, replyMarkup: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaAuto(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BotInlineMessage.botInlineMessageMediaAuto(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaVenue(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
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
            var _8: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.BotInlineMessage.botInlineMessageMediaVenue(flags: _1!, geo: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!, replyMarkup: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaContact(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BotInlineMessage.botInlineMessageMediaContact(flags: _1!, phoneNumber: _2!, firstName: _3!, lastName: _4!, vcard: _5!, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputPeerNotifySettings: TypeConstructorDescription {
        case inputPeerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPeerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound):
                    if boxed {
                        buffer.appendInt32(-1673717362)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {showPreviews!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {silent!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(muteUntil!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(sound!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPeerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound):
                return ("inputPeerNotifySettings", [("flags", flags), ("showPreviews", showPreviews), ("silent", silent), ("muteUntil", muteUntil), ("sound", sound)])
    }
    }
    
        public static func parse_inputPeerNotifySettings(_ reader: BufferReader) -> InputPeerNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, sound: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ExportedChatInvite: TypeConstructorDescription {
        case chatInviteEmpty
        case chatInviteExported(link: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatInviteEmpty:
                    if boxed {
                        buffer.appendInt32(1776236393)
                    }
                    
                    break
                case .chatInviteExported(let link):
                    if boxed {
                        buffer.appendInt32(-64092740)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatInviteEmpty:
                return ("chatInviteEmpty", [])
                case .chatInviteExported(let link):
                return ("chatInviteExported", [("link", link)])
    }
    }
    
        public static func parse_chatInviteEmpty(_ reader: BufferReader) -> ExportedChatInvite? {
            return Api.ExportedChatInvite.chatInviteEmpty
        }
        public static func parse_chatInviteExported(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ExportedChatInvite.chatInviteExported(link: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Authorization: TypeConstructorDescription {
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
                return ("authorization", [("flags", flags), ("hash", hash), ("deviceModel", deviceModel), ("platform", platform), ("systemVersion", systemVersion), ("apiId", apiId), ("appName", appName), ("appVersion", appVersion), ("dateCreated", dateCreated), ("dateActive", dateActive), ("ip", ip), ("country", country), ("region", region)])
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
    public enum MaskCoords: TypeConstructorDescription {
        case maskCoords(n: Int32, x: Double, y: Double, zoom: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .maskCoords(let n, let x, let y, let zoom):
                    if boxed {
                        buffer.appendInt32(-1361650766)
                    }
                    serializeInt32(n, buffer: buffer, boxed: false)
                    serializeDouble(x, buffer: buffer, boxed: false)
                    serializeDouble(y, buffer: buffer, boxed: false)
                    serializeDouble(zoom, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .maskCoords(let n, let x, let y, let zoom):
                return ("maskCoords", [("n", n), ("x", x), ("y", y), ("zoom", zoom)])
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
                return Api.MaskCoords.maskCoords(n: _1!, x: _2!, y: _3!, zoom: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PhoneConnection: TypeConstructorDescription {
        case phoneConnection(id: Int64, ip: String, ipv6: String, port: Int32, peerTag: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneConnection(let id, let ip, let ipv6, let port, let peerTag):
                    if boxed {
                        buffer.appendInt32(-1655957568)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(ip, buffer: buffer, boxed: false)
                    serializeString(ipv6, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    serializeBytes(peerTag, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneConnection(let id, let ip, let ipv6, let port, let peerTag):
                return ("phoneConnection", [("id", id), ("ip", ip), ("ipv6", ipv6), ("port", port), ("peerTag", peerTag)])
    }
    }
    
        public static func parse_phoneConnection(_ reader: BufferReader) -> PhoneConnection? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PhoneConnection.phoneConnection(id: _1!, ip: _2!, ipv6: _3!, port: _4!, peerTag: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AccountDaysTTL: TypeConstructorDescription {
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
                return ("accountDaysTTL", [("days", days)])
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
    public enum SecureValueType: TypeConstructorDescription {
        case secureValueTypePersonalDetails
        case secureValueTypePassport
        case secureValueTypeDriverLicense
        case secureValueTypeIdentityCard
        case secureValueTypeInternalPassport
        case secureValueTypeAddress
        case secureValueTypeUtilityBill
        case secureValueTypeBankStatement
        case secureValueTypeRentalAgreement
        case secureValueTypePassportRegistration
        case secureValueTypeTemporaryRegistration
        case secureValueTypePhone
        case secureValueTypeEmail
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueTypePersonalDetails:
                    if boxed {
                        buffer.appendInt32(-1658158621)
                    }
                    
                    break
                case .secureValueTypePassport:
                    if boxed {
                        buffer.appendInt32(1034709504)
                    }
                    
                    break
                case .secureValueTypeDriverLicense:
                    if boxed {
                        buffer.appendInt32(115615172)
                    }
                    
                    break
                case .secureValueTypeIdentityCard:
                    if boxed {
                        buffer.appendInt32(-1596951477)
                    }
                    
                    break
                case .secureValueTypeInternalPassport:
                    if boxed {
                        buffer.appendInt32(-1717268701)
                    }
                    
                    break
                case .secureValueTypeAddress:
                    if boxed {
                        buffer.appendInt32(-874308058)
                    }
                    
                    break
                case .secureValueTypeUtilityBill:
                    if boxed {
                        buffer.appendInt32(-63531698)
                    }
                    
                    break
                case .secureValueTypeBankStatement:
                    if boxed {
                        buffer.appendInt32(-1995211763)
                    }
                    
                    break
                case .secureValueTypeRentalAgreement:
                    if boxed {
                        buffer.appendInt32(-1954007928)
                    }
                    
                    break
                case .secureValueTypePassportRegistration:
                    if boxed {
                        buffer.appendInt32(-1713143702)
                    }
                    
                    break
                case .secureValueTypeTemporaryRegistration:
                    if boxed {
                        buffer.appendInt32(-368907213)
                    }
                    
                    break
                case .secureValueTypePhone:
                    if boxed {
                        buffer.appendInt32(-1289704741)
                    }
                    
                    break
                case .secureValueTypeEmail:
                    if boxed {
                        buffer.appendInt32(-1908627474)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueTypePersonalDetails:
                return ("secureValueTypePersonalDetails", [])
                case .secureValueTypePassport:
                return ("secureValueTypePassport", [])
                case .secureValueTypeDriverLicense:
                return ("secureValueTypeDriverLicense", [])
                case .secureValueTypeIdentityCard:
                return ("secureValueTypeIdentityCard", [])
                case .secureValueTypeInternalPassport:
                return ("secureValueTypeInternalPassport", [])
                case .secureValueTypeAddress:
                return ("secureValueTypeAddress", [])
                case .secureValueTypeUtilityBill:
                return ("secureValueTypeUtilityBill", [])
                case .secureValueTypeBankStatement:
                return ("secureValueTypeBankStatement", [])
                case .secureValueTypeRentalAgreement:
                return ("secureValueTypeRentalAgreement", [])
                case .secureValueTypePassportRegistration:
                return ("secureValueTypePassportRegistration", [])
                case .secureValueTypeTemporaryRegistration:
                return ("secureValueTypeTemporaryRegistration", [])
                case .secureValueTypePhone:
                return ("secureValueTypePhone", [])
                case .secureValueTypeEmail:
                return ("secureValueTypeEmail", [])
    }
    }
    
        public static func parse_secureValueTypePersonalDetails(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePersonalDetails
        }
        public static func parse_secureValueTypePassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassport
        }
        public static func parse_secureValueTypeDriverLicense(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeDriverLicense
        }
        public static func parse_secureValueTypeIdentityCard(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeIdentityCard
        }
        public static func parse_secureValueTypeInternalPassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeInternalPassport
        }
        public static func parse_secureValueTypeAddress(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeAddress
        }
        public static func parse_secureValueTypeUtilityBill(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeUtilityBill
        }
        public static func parse_secureValueTypeBankStatement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeBankStatement
        }
        public static func parse_secureValueTypeRentalAgreement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeRentalAgreement
        }
        public static func parse_secureValueTypePassportRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassportRegistration
        }
        public static func parse_secureValueTypeTemporaryRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeTemporaryRegistration
        }
        public static func parse_secureValueTypePhone(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePhone
        }
        public static func parse_secureValueTypeEmail(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeEmail
        }
    
    }
    public enum PasswordKdfAlgo: TypeConstructorDescription {
        case passwordKdfAlgoUnknown
        case passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(salt1: Buffer, salt2: Buffer, g: Int32, p: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordKdfAlgoUnknown:
                    if boxed {
                        buffer.appendInt32(-732254058)
                    }
                    
                    break
                case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let salt1, let salt2, let g, let p):
                    if boxed {
                        buffer.appendInt32(982592842)
                    }
                    serializeBytes(salt1, buffer: buffer, boxed: false)
                    serializeBytes(salt2, buffer: buffer, boxed: false)
                    serializeInt32(g, buffer: buffer, boxed: false)
                    serializeBytes(p, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordKdfAlgoUnknown:
                return ("passwordKdfAlgoUnknown", [])
                case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let salt1, let salt2, let g, let p):
                return ("passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow", [("salt1", salt1), ("salt2", salt2), ("g", g), ("p", p)])
    }
    }
    
        public static func parse_passwordKdfAlgoUnknown(_ reader: BufferReader) -> PasswordKdfAlgo? {
            return Api.PasswordKdfAlgo.passwordKdfAlgoUnknown
        }
        public static func parse_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(_ reader: BufferReader) -> PasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PasswordKdfAlgo.passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(salt1: _1!, salt2: _2!, g: _3!, p: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputBotInlineResult: TypeConstructorDescription {
        case inputBotInlineResultPhoto(id: String, type: String, photo: Api.InputPhoto, sendMessage: Api.InputBotInlineMessage)
        case inputBotInlineResultDocument(flags: Int32, id: String, type: String, title: String?, description: String?, document: Api.InputDocument, sendMessage: Api.InputBotInlineMessage)
        case inputBotInlineResultGame(id: String, shortName: String, sendMessage: Api.InputBotInlineMessage)
        case inputBotInlineResult(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.InputWebDocument?, content: Api.InputWebDocument?, sendMessage: Api.InputBotInlineMessage)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotInlineResultPhoto(let id, let type, let photo, let sendMessage):
                    if boxed {
                        buffer.appendInt32(-1462213465)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    sendMessage.serialize(buffer, true)
                    break
                case .inputBotInlineResultDocument(let flags, let id, let type, let title, let description, let document, let sendMessage):
                    if boxed {
                        buffer.appendInt32(-459324)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    document.serialize(buffer, true)
                    sendMessage.serialize(buffer, true)
                    break
                case .inputBotInlineResultGame(let id, let shortName, let sendMessage):
                    if boxed {
                        buffer.appendInt32(1336154098)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    sendMessage.serialize(buffer, true)
                    break
                case .inputBotInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                    if boxed {
                        buffer.appendInt32(-2000710887)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {thumb!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {content!.serialize(buffer, true)}
                    sendMessage.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineResultPhoto(let id, let type, let photo, let sendMessage):
                return ("inputBotInlineResultPhoto", [("id", id), ("type", type), ("photo", photo), ("sendMessage", sendMessage)])
                case .inputBotInlineResultDocument(let flags, let id, let type, let title, let description, let document, let sendMessage):
                return ("inputBotInlineResultDocument", [("flags", flags), ("id", id), ("type", type), ("title", title), ("description", description), ("document", document), ("sendMessage", sendMessage)])
                case .inputBotInlineResultGame(let id, let shortName, let sendMessage):
                return ("inputBotInlineResultGame", [("id", id), ("shortName", shortName), ("sendMessage", sendMessage)])
                case .inputBotInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                return ("inputBotInlineResult", [("flags", flags), ("id", id), ("type", type), ("title", title), ("description", description), ("url", url), ("thumb", thumb), ("content", content), ("sendMessage", sendMessage)])
    }
    }
    
        public static func parse_inputBotInlineResultPhoto(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            var _4: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineResult.inputBotInlineResultPhoto(id: _1!, type: _2!, photo: _3!, sendMessage: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultDocument(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: Api.InputDocument?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _7: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputBotInlineResult.inputBotInlineResultDocument(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, document: _6!, sendMessage: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultGame(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineResult.inputBotInlineResultGame(id: _1!, shortName: _2!, sendMessage: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResult(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _8: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _9: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputBotInlineResult.inputBotInlineResult(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, url: _6, thumb: _7, content: _8, sendMessage: _9!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PrivacyRule: TypeConstructorDescription {
        case privacyValueAllowContacts
        case privacyValueAllowAll
        case privacyValueAllowUsers(users: [Int32])
        case privacyValueDisallowContacts
        case privacyValueDisallowAll
        case privacyValueDisallowUsers(users: [Int32])
        case privacyValueAllowChatParticipants(chats: [Int32])
        case privacyValueDisallowChatParticipants(chats: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyValueAllowContacts:
                    if boxed {
                        buffer.appendInt32(-123988)
                    }
                    
                    break
                case .privacyValueAllowAll:
                    if boxed {
                        buffer.appendInt32(1698855810)
                    }
                    
                    break
                case .privacyValueAllowUsers(let users):
                    if boxed {
                        buffer.appendInt32(1297858060)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueDisallowContacts:
                    if boxed {
                        buffer.appendInt32(-125240806)
                    }
                    
                    break
                case .privacyValueDisallowAll:
                    if boxed {
                        buffer.appendInt32(-1955338397)
                    }
                    
                    break
                case .privacyValueDisallowUsers(let users):
                    if boxed {
                        buffer.appendInt32(209668535)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueAllowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(415136107)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueDisallowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(-1397881200)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .privacyValueAllowContacts:
                return ("privacyValueAllowContacts", [])
                case .privacyValueAllowAll:
                return ("privacyValueAllowAll", [])
                case .privacyValueAllowUsers(let users):
                return ("privacyValueAllowUsers", [("users", users)])
                case .privacyValueDisallowContacts:
                return ("privacyValueDisallowContacts", [])
                case .privacyValueDisallowAll:
                return ("privacyValueDisallowAll", [])
                case .privacyValueDisallowUsers(let users):
                return ("privacyValueDisallowUsers", [("users", users)])
                case .privacyValueAllowChatParticipants(let chats):
                return ("privacyValueAllowChatParticipants", [("chats", chats)])
                case .privacyValueDisallowChatParticipants(let chats):
                return ("privacyValueDisallowChatParticipants", [("chats", chats)])
    }
    }
    
        public static func parse_privacyValueAllowContacts(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowContacts
        }
        public static func parse_privacyValueAllowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowAll
        }
        public static func parse_privacyValueAllowUsers(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowContacts(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowContacts
        }
        public static func parse_privacyValueDisallowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowAll
        }
        public static func parse_privacyValueDisallowUsers(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueAllowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageAction: TypeConstructorDescription {
        case messageActionEmpty
        case messageActionChatCreate(title: String, users: [Int32])
        case messageActionChatEditTitle(title: String)
        case messageActionChatEditPhoto(photo: Api.Photo)
        case messageActionChatDeletePhoto
        case messageActionChatAddUser(users: [Int32])
        case messageActionChatDeleteUser(userId: Int32)
        case messageActionChatJoinedByLink(inviterId: Int32)
        case messageActionChannelCreate(title: String)
        case messageActionChatMigrateTo(channelId: Int32)
        case messageActionChannelMigrateFrom(title: String, chatId: Int32)
        case messageActionPinMessage
        case messageActionHistoryClear
        case messageActionGameScore(gameId: Int64, score: Int32)
        case messageActionPaymentSentMe(flags: Int32, currency: String, totalAmount: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, charge: Api.PaymentCharge)
        case messageActionPaymentSent(currency: String, totalAmount: Int64)
        case messageActionPhoneCall(flags: Int32, callId: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case messageActionScreenshotTaken
        case messageActionCustomAction(message: String)
        case messageActionBotAllowed(domain: String)
        case messageActionSecureValuesSentMe(values: [Api.SecureValue], credentials: Api.SecureCredentialsEncrypted)
        case messageActionSecureValuesSent(types: [Api.SecureValueType])
        case messageActionContactSignUp
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageActionEmpty:
                    if boxed {
                        buffer.appendInt32(-1230047312)
                    }
                    
                    break
                case .messageActionChatCreate(let title, let users):
                    if boxed {
                        buffer.appendInt32(-1503425638)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionChatEditTitle(let title):
                    if boxed {
                        buffer.appendInt32(-1247687078)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .messageActionChatEditPhoto(let photo):
                    if boxed {
                        buffer.appendInt32(2144015272)
                    }
                    photo.serialize(buffer, true)
                    break
                case .messageActionChatDeletePhoto:
                    if boxed {
                        buffer.appendInt32(-1780220945)
                    }
                    
                    break
                case .messageActionChatAddUser(let users):
                    if boxed {
                        buffer.appendInt32(1217033015)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionChatDeleteUser(let userId):
                    if boxed {
                        buffer.appendInt32(-1297179892)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatJoinedByLink(let inviterId):
                    if boxed {
                        buffer.appendInt32(-123931160)
                    }
                    serializeInt32(inviterId, buffer: buffer, boxed: false)
                    break
                case .messageActionChannelCreate(let title):
                    if boxed {
                        buffer.appendInt32(-1781355374)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .messageActionChatMigrateTo(let channelId):
                    if boxed {
                        buffer.appendInt32(1371385889)
                    }
                    serializeInt32(channelId, buffer: buffer, boxed: false)
                    break
                case .messageActionChannelMigrateFrom(let title, let chatId):
                    if boxed {
                        buffer.appendInt32(-1336546578)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .messageActionPinMessage:
                    if boxed {
                        buffer.appendInt32(-1799538451)
                    }
                    
                    break
                case .messageActionHistoryClear:
                    if boxed {
                        buffer.appendInt32(-1615153660)
                    }
                    
                    break
                case .messageActionGameScore(let gameId, let score):
                    if boxed {
                        buffer.appendInt32(-1834538890)
                    }
                    serializeInt64(gameId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
                case .messageActionPaymentSentMe(let flags, let currency, let totalAmount, let payload, let info, let shippingOptionId, let charge):
                    if boxed {
                        buffer.appendInt32(-1892568281)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    charge.serialize(buffer, true)
                    break
                case .messageActionPaymentSent(let currency, let totalAmount):
                    if boxed {
                        buffer.appendInt32(1080663248)
                    }
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    break
                case .messageActionPhoneCall(let flags, let callId, let reason, let duration):
                    if boxed {
                        buffer.appendInt32(-2132731265)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(callId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {reason!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    break
                case .messageActionScreenshotTaken:
                    if boxed {
                        buffer.appendInt32(1200788123)
                    }
                    
                    break
                case .messageActionCustomAction(let message):
                    if boxed {
                        buffer.appendInt32(-85549226)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    break
                case .messageActionBotAllowed(let domain):
                    if boxed {
                        buffer.appendInt32(-1410748418)
                    }
                    serializeString(domain, buffer: buffer, boxed: false)
                    break
                case .messageActionSecureValuesSentMe(let values, let credentials):
                    if boxed {
                        buffer.appendInt32(455635795)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(values.count))
                    for item in values {
                        item.serialize(buffer, true)
                    }
                    credentials.serialize(buffer, true)
                    break
                case .messageActionSecureValuesSent(let types):
                    if boxed {
                        buffer.appendInt32(-648257196)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    break
                case .messageActionContactSignUp:
                    if boxed {
                        buffer.appendInt32(-202219658)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageActionEmpty:
                return ("messageActionEmpty", [])
                case .messageActionChatCreate(let title, let users):
                return ("messageActionChatCreate", [("title", title), ("users", users)])
                case .messageActionChatEditTitle(let title):
                return ("messageActionChatEditTitle", [("title", title)])
                case .messageActionChatEditPhoto(let photo):
                return ("messageActionChatEditPhoto", [("photo", photo)])
                case .messageActionChatDeletePhoto:
                return ("messageActionChatDeletePhoto", [])
                case .messageActionChatAddUser(let users):
                return ("messageActionChatAddUser", [("users", users)])
                case .messageActionChatDeleteUser(let userId):
                return ("messageActionChatDeleteUser", [("userId", userId)])
                case .messageActionChatJoinedByLink(let inviterId):
                return ("messageActionChatJoinedByLink", [("inviterId", inviterId)])
                case .messageActionChannelCreate(let title):
                return ("messageActionChannelCreate", [("title", title)])
                case .messageActionChatMigrateTo(let channelId):
                return ("messageActionChatMigrateTo", [("channelId", channelId)])
                case .messageActionChannelMigrateFrom(let title, let chatId):
                return ("messageActionChannelMigrateFrom", [("title", title), ("chatId", chatId)])
                case .messageActionPinMessage:
                return ("messageActionPinMessage", [])
                case .messageActionHistoryClear:
                return ("messageActionHistoryClear", [])
                case .messageActionGameScore(let gameId, let score):
                return ("messageActionGameScore", [("gameId", gameId), ("score", score)])
                case .messageActionPaymentSentMe(let flags, let currency, let totalAmount, let payload, let info, let shippingOptionId, let charge):
                return ("messageActionPaymentSentMe", [("flags", flags), ("currency", currency), ("totalAmount", totalAmount), ("payload", payload), ("info", info), ("shippingOptionId", shippingOptionId), ("charge", charge)])
                case .messageActionPaymentSent(let currency, let totalAmount):
                return ("messageActionPaymentSent", [("currency", currency), ("totalAmount", totalAmount)])
                case .messageActionPhoneCall(let flags, let callId, let reason, let duration):
                return ("messageActionPhoneCall", [("flags", flags), ("callId", callId), ("reason", reason), ("duration", duration)])
                case .messageActionScreenshotTaken:
                return ("messageActionScreenshotTaken", [])
                case .messageActionCustomAction(let message):
                return ("messageActionCustomAction", [("message", message)])
                case .messageActionBotAllowed(let domain):
                return ("messageActionBotAllowed", [("domain", domain)])
                case .messageActionSecureValuesSentMe(let values, let credentials):
                return ("messageActionSecureValuesSentMe", [("values", values), ("credentials", credentials)])
                case .messageActionSecureValuesSent(let types):
                return ("messageActionSecureValuesSent", [("types", types)])
                case .messageActionContactSignUp:
                return ("messageActionContactSignUp", [])
    }
    }
    
        public static func parse_messageActionEmpty(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionEmpty
        }
        public static func parse_messageActionChatCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChatCreate(title: _1!, users: _2!)
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
                return Api.MessageAction.messageActionChatEditTitle(title: _1!)
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
                return Api.MessageAction.messageActionChatEditPhoto(photo: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatDeletePhoto(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatDeletePhoto
        }
        public static func parse_messageActionChatAddUser(_ reader: BufferReader) -> MessageAction? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatAddUser(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatDeleteUser(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatDeleteUser(userId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByLink(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatJoinedByLink(inviterId: _1!)
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
                return Api.MessageAction.messageActionChannelCreate(title: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatMigrateTo(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatMigrateTo(channelId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelMigrateFrom(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChannelMigrateFrom(title: _1!, chatId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPinMessage(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionPinMessage
        }
        public static func parse_messageActionHistoryClear(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionHistoryClear
        }
        public static func parse_messageActionGameScore(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGameScore(gameId: _1!, score: _2!)
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = parseString(reader) }
            var _7: Api.PaymentCharge?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PaymentCharge
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageAction.messageActionPaymentSentMe(flags: _1!, currency: _2!, totalAmount: _3!, payload: _4!, info: _5, shippingOptionId: _6, charge: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSent(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionPaymentSent(currency: _1!, totalAmount: _2!)
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PhoneCallDiscardReason
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionPhoneCall(flags: _1!, callId: _2!, reason: _3, duration: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionScreenshotTaken(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionScreenshotTaken
        }
        public static func parse_messageActionCustomAction(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionCustomAction(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionBotAllowed(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionBotAllowed(domain: _1!)
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
                return Api.MessageAction.messageActionSecureValuesSentMe(values: _1!, credentials: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSecureValuesSent(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValueType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSecureValuesSent(types: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionContactSignUp(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionContactSignUp
        }
    
    }
    public enum PhoneCall: TypeConstructorDescription {
        case phoneCallEmpty(id: Int64)
        case phoneCallWaiting(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, protocol: Api.PhoneCallProtocol, receiveDate: Int32?)
        case phoneCallRequested(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, gAHash: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallAccepted(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, gB: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCall(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, gAOrB: Buffer, keyFingerprint: Int64, protocol: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32)
        case phoneCallDiscarded(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCallEmpty(let id):
                    if boxed {
                        buffer.appendInt32(1399245077)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .phoneCallWaiting(let flags, let id, let accessHash, let date, let adminId, let participantId, let `protocol`, let receiveDate):
                    if boxed {
                        buffer.appendInt32(462375633)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(receiveDate!, buffer: buffer, boxed: false)}
                    break
                case .phoneCallRequested(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAHash, let `protocol`):
                    if boxed {
                        buffer.appendInt32(-2014659757)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gAHash, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    break
                case .phoneCallAccepted(let flags, let id, let accessHash, let date, let adminId, let participantId, let gB, let `protocol`):
                    if boxed {
                        buffer.appendInt32(-1719909046)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    break
                case .phoneCall(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint, let `protocol`, let connections, let startDate):
                    if boxed {
                        buffer.appendInt32(-2025673089)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gAOrB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(connections.count))
                    for item in connections {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    break
                case .phoneCallDiscarded(let flags, let id, let reason, let duration):
                    if boxed {
                        buffer.appendInt32(1355435489)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {reason!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCallEmpty(let id):
                return ("phoneCallEmpty", [("id", id)])
                case .phoneCallWaiting(let flags, let id, let accessHash, let date, let adminId, let participantId, let `protocol`, let receiveDate):
                return ("phoneCallWaiting", [("flags", flags), ("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId), ("`protocol`", `protocol`), ("receiveDate", receiveDate)])
                case .phoneCallRequested(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAHash, let `protocol`):
                return ("phoneCallRequested", [("flags", flags), ("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId), ("gAHash", gAHash), ("`protocol`", `protocol`)])
                case .phoneCallAccepted(let flags, let id, let accessHash, let date, let adminId, let participantId, let gB, let `protocol`):
                return ("phoneCallAccepted", [("flags", flags), ("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId), ("gB", gB), ("`protocol`", `protocol`)])
                case .phoneCall(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint, let `protocol`, let connections, let startDate):
                return ("phoneCall", [("flags", flags), ("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId), ("gAOrB", gAOrB), ("keyFingerprint", keyFingerprint), ("`protocol`", `protocol`), ("connections", connections), ("startDate", startDate)])
                case .phoneCallDiscarded(let flags, let id, let reason, let duration):
                return ("phoneCallDiscarded", [("flags", flags), ("id", id), ("reason", reason), ("duration", duration)])
    }
    }
    
        public static func parse_phoneCallEmpty(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.PhoneCall.phoneCallEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneCallWaiting(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.PhoneCallProtocol?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PhoneCallProtocol
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_8 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PhoneCall.phoneCallWaiting(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, protocol: _7!, receiveDate: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneCallRequested(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Buffer?
            _7 = parseBytes(reader)
            var _8: Api.PhoneCallProtocol?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.PhoneCallProtocol
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PhoneCall.phoneCallRequested(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, gAHash: _7!, protocol: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneCallAccepted(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Buffer?
            _7 = parseBytes(reader)
            var _8: Api.PhoneCallProtocol?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.PhoneCallProtocol
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PhoneCall.phoneCallAccepted(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, gB: _7!, protocol: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Buffer?
            _7 = parseBytes(reader)
            var _8: Int64?
            _8 = reader.readInt64()
            var _9: Api.PhoneCallProtocol?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PhoneCallProtocol
            }
            var _10: [Api.PhoneConnection]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhoneConnection.self)
            }
            var _11: Int32?
            _11 = reader.readInt32()
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.PhoneCall.phoneCall(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, gAOrB: _7!, keyFingerprint: _8!, protocol: _9!, connections: _10!, startDate: _11!)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneCallDiscarded(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PhoneCallDiscardReason?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PhoneCallDiscardReason
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PhoneCall.phoneCallDiscarded(flags: _1!, id: _2!, reason: _3, duration: _4)
            }
            else {
                return nil
            }
        }
    
    }
    public enum DialogPeer: TypeConstructorDescription {
        case dialogPeer(peer: Api.Peer)
        case dialogPeerFolder(folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialogPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-445792507)
                    }
                    peer.serialize(buffer, true)
                    break
                case .dialogPeerFolder(let folderId):
                    if boxed {
                        buffer.appendInt32(1363483106)
                    }
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dialogPeer(let peer):
                return ("dialogPeer", [("peer", peer)])
                case .dialogPeerFolder(let folderId):
                return ("dialogPeerFolder", [("folderId", folderId)])
    }
    }
    
        public static func parse_dialogPeer(_ reader: BufferReader) -> DialogPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.DialogPeer.dialogPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_dialogPeerFolder(_ reader: BufferReader) -> DialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.DialogPeer.dialogPeerFolder(folderId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WebDocument: TypeConstructorDescription {
        case webDocumentNoProxy(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
        case webDocument(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webDocumentNoProxy(let url, let size, let mimeType, let attributes):
                    if boxed {
                        buffer.appendInt32(-104284986)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
                case .webDocument(let url, let accessHash, let size, let mimeType, let attributes):
                    if boxed {
                        buffer.appendInt32(475467473)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webDocumentNoProxy(let url, let size, let mimeType, let attributes):
                return ("webDocumentNoProxy", [("url", url), ("size", size), ("mimeType", mimeType), ("attributes", attributes)])
                case .webDocument(let url, let accessHash, let size, let mimeType, let attributes):
                return ("webDocument", [("url", url), ("accessHash", accessHash), ("size", size), ("mimeType", mimeType), ("attributes", attributes)])
    }
    }
    
        public static func parse_webDocumentNoProxy(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebDocument.webDocumentNoProxy(url: _1!, size: _2!, mimeType: _3!, attributes: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_webDocument(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.WebDocument.webDocument(url: _1!, accessHash: _2!, size: _3!, mimeType: _4!, attributes: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Theme: TypeConstructorDescription {
        case theme(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: Api.ThemeSettings?, installsCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .theme(let flags, let id, let accessHash, let slug, let title, let document, let settings, let installsCount):
                    if boxed {
                        buffer.appendInt32(42930452)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {settings!.serialize(buffer, true)}
                    serializeInt32(installsCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .theme(let flags, let id, let accessHash, let slug, let title, let document, let settings, let installsCount):
                return ("theme", [("flags", flags), ("id", id), ("accessHash", accessHash), ("slug", slug), ("title", title), ("document", document), ("settings", settings), ("installsCount", installsCount)])
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
            var _7: Api.ThemeSettings?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ThemeSettings
            } }
            var _8: Int32?
            _8 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Theme.theme(flags: _1!, id: _2!, accessHash: _3!, slug: _4!, title: _5!, document: _6, settings: _7, installsCount: _8!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelAdminLogEventsFilter: TypeConstructorDescription {
        case channelAdminLogEventsFilter(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEventsFilter(let flags):
                    if boxed {
                        buffer.appendInt32(-368018716)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEventsFilter(let flags):
                return ("channelAdminLogEventsFilter", [("flags", flags)])
    }
    }
    
        public static func parse_channelAdminLogEventsFilter(_ reader: BufferReader) -> ChannelAdminLogEventsFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventsFilter.channelAdminLogEventsFilter(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ThemeSettings: TypeConstructorDescription {
        case themeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, messageTopColor: Int32?, messageBottomColor: Int32?, wallpaper: Api.WallPaper?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .themeSettings(let flags, let baseTheme, let accentColor, let messageTopColor, let messageBottomColor, let wallpaper):
                    if boxed {
                        buffer.appendInt32(-1676371894)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    baseTheme.serialize(buffer, true)
                    serializeInt32(accentColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(messageTopColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(messageBottomColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaper!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .themeSettings(let flags, let baseTheme, let accentColor, let messageTopColor, let messageBottomColor, let wallpaper):
                return ("themeSettings", [("flags", flags), ("baseTheme", baseTheme), ("accentColor", accentColor), ("messageTopColor", messageTopColor), ("messageBottomColor", messageBottomColor), ("wallpaper", wallpaper)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Api.WallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WallPaper
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ThemeSettings.themeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, messageTopColor: _4, messageBottomColor: _5, wallpaper: _6)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PeerNotifySettings: TypeConstructorDescription {
        case peerNotifySettingsEmpty
        case peerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerNotifySettingsEmpty:
                    if boxed {
                        buffer.appendInt32(1889961234)
                    }
                    
                    break
                case .peerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound):
                    if boxed {
                        buffer.appendInt32(-1353671392)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {showPreviews!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {silent!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(muteUntil!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(sound!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerNotifySettingsEmpty:
                return ("peerNotifySettingsEmpty", [])
                case .peerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound):
                return ("peerNotifySettings", [("flags", flags), ("showPreviews", showPreviews), ("silent", silent), ("muteUntil", muteUntil), ("sound", sound)])
    }
    }
    
        public static func parse_peerNotifySettingsEmpty(_ reader: BufferReader) -> PeerNotifySettings? {
            return Api.PeerNotifySettings.peerNotifySettingsEmpty
        }
        public static func parse_peerNotifySettings(_ reader: BufferReader) -> PeerNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PeerNotifySettings.peerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, sound: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputBotInlineMessageID: TypeConstructorDescription {
        case inputBotInlineMessageID(dcId: Int32, id: Int64, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotInlineMessageID(let dcId, let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1995686519)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineMessageID(let dcId, let id, let accessHash):
                return ("inputBotInlineMessageID", [("dcId", dcId), ("id", id), ("accessHash", accessHash)])
    }
    }
    
        public static func parse_inputBotInlineMessageID(_ reader: BufferReader) -> InputBotInlineMessageID? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineMessageID.inputBotInlineMessageID(dcId: _1!, id: _2!, accessHash: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PageRelatedArticle: TypeConstructorDescription {
        case pageRelatedArticle(flags: Int32, url: String, webpageId: Int64, title: String?, description: String?, photoId: Int64?, author: String?, publishedDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageRelatedArticle(let flags, let url, let webpageId, let title, let description, let photoId, let author, let publishedDate):
                    if boxed {
                        buffer.appendInt32(-1282352120)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(webpageId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(photoId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(author!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(publishedDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageRelatedArticle(let flags, let url, let webpageId, let title, let description, let photoId, let author, let publishedDate):
                return ("pageRelatedArticle", [("flags", flags), ("url", url), ("webpageId", webpageId), ("title", title), ("description", description), ("photoId", photoId), ("author", author), ("publishedDate", publishedDate)])
    }
    }
    
        public static func parse_pageRelatedArticle(_ reader: BufferReader) -> PageRelatedArticle? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt64() }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = parseString(reader) }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PageRelatedArticle.pageRelatedArticle(flags: _1!, url: _2!, webpageId: _3!, title: _4, description: _5, photoId: _6, author: _7, publishedDate: _8)
            }
            else {
                return nil
            }
        }
    
    }
    public enum StickerPack: TypeConstructorDescription {
        case stickerPack(emoticon: String, documents: [Int64])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerPack(let emoticon, let documents):
                    if boxed {
                        buffer.appendInt32(313694676)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerPack(let emoticon, let documents):
                return ("stickerPack", [("emoticon", emoticon), ("documents", documents)])
    }
    }
    
        public static func parse_stickerPack(_ reader: BufferReader) -> StickerPack? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerPack.stickerPack(emoticon: _1!, documents: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum UserProfilePhoto: TypeConstructorDescription {
        case userProfilePhotoEmpty
        case userProfilePhoto(photoId: Int64, photoSmall: Api.FileLocation, photoBig: Api.FileLocation, dcId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userProfilePhotoEmpty:
                    if boxed {
                        buffer.appendInt32(1326562017)
                    }
                    
                    break
                case .userProfilePhoto(let photoId, let photoSmall, let photoBig, let dcId):
                    if boxed {
                        buffer.appendInt32(-321430132)
                    }
                    serializeInt64(photoId, buffer: buffer, boxed: false)
                    photoSmall.serialize(buffer, true)
                    photoBig.serialize(buffer, true)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userProfilePhotoEmpty:
                return ("userProfilePhotoEmpty", [])
                case .userProfilePhoto(let photoId, let photoSmall, let photoBig, let dcId):
                return ("userProfilePhoto", [("photoId", photoId), ("photoSmall", photoSmall), ("photoBig", photoBig), ("dcId", dcId)])
    }
    }
    
        public static func parse_userProfilePhotoEmpty(_ reader: BufferReader) -> UserProfilePhoto? {
            return Api.UserProfilePhoto.userProfilePhotoEmpty
        }
        public static func parse_userProfilePhoto(_ reader: BufferReader) -> UserProfilePhoto? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.FileLocation?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.FileLocation
            }
            var _3: Api.FileLocation?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.FileLocation
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.UserProfilePhoto.userProfilePhoto(photoId: _1!, photoSmall: _2!, photoBig: _3!, dcId: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChatOnlines: TypeConstructorDescription {
        case chatOnlines(onlines: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatOnlines(let onlines):
                    if boxed {
                        buffer.appendInt32(-264117680)
                    }
                    serializeInt32(onlines, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatOnlines(let onlines):
                return ("chatOnlines", [("onlines", onlines)])
    }
    }
    
        public static func parse_chatOnlines(_ reader: BufferReader) -> ChatOnlines? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatOnlines.chatOnlines(onlines: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputAppEvent: TypeConstructorDescription {
        case inputAppEvent(time: Double, type: String, peer: Int64, data: Api.JSONValue)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputAppEvent(let time, let type, let peer, let data):
                    if boxed {
                        buffer.appendInt32(488313413)
                    }
                    serializeDouble(time, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeInt64(peer, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputAppEvent(let time, let type, let peer, let data):
                return ("inputAppEvent", [("time", time), ("type", type), ("peer", peer), ("data", data)])
    }
    }
    
        public static func parse_inputAppEvent(_ reader: BufferReader) -> InputAppEvent? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.JSONValue?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputAppEvent.inputAppEvent(time: _1!, type: _2!, peer: _3!, data: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageEntity: TypeConstructorDescription {
        case messageEntityUnknown(offset: Int32, length: Int32)
        case messageEntityMention(offset: Int32, length: Int32)
        case messageEntityHashtag(offset: Int32, length: Int32)
        case messageEntityBotCommand(offset: Int32, length: Int32)
        case messageEntityUrl(offset: Int32, length: Int32)
        case messageEntityEmail(offset: Int32, length: Int32)
        case messageEntityBold(offset: Int32, length: Int32)
        case messageEntityItalic(offset: Int32, length: Int32)
        case messageEntityCode(offset: Int32, length: Int32)
        case messageEntityPre(offset: Int32, length: Int32, language: String)
        case messageEntityTextUrl(offset: Int32, length: Int32, url: String)
        case messageEntityMentionName(offset: Int32, length: Int32, userId: Int32)
        case inputMessageEntityMentionName(offset: Int32, length: Int32, userId: Api.InputUser)
        case messageEntityPhone(offset: Int32, length: Int32)
        case messageEntityCashtag(offset: Int32, length: Int32)
        case messageEntityUnderline(offset: Int32, length: Int32)
        case messageEntityStrike(offset: Int32, length: Int32)
        case messageEntityBlockquote(offset: Int32, length: Int32)
        case messageEntityBankCard(offset: Int32, length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageEntityUnknown(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1148011883)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityMention(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-100378723)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityHashtag(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1868782349)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBotCommand(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1827637959)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityUrl(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1859134776)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityEmail(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1692693954)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBold(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1117713463)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityItalic(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-2106619040)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCode(let offset, let length):
                    if boxed {
                        buffer.appendInt32(681706865)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityPre(let offset, let length, let language):
                    if boxed {
                        buffer.appendInt32(1938967520)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeString(language, buffer: buffer, boxed: false)
                    break
                case .messageEntityTextUrl(let offset, let length, let url):
                    if boxed {
                        buffer.appendInt32(1990644519)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .messageEntityMentionName(let offset, let length, let userId):
                    if boxed {
                        buffer.appendInt32(892193368)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .inputMessageEntityMentionName(let offset, let length, let userId):
                    if boxed {
                        buffer.appendInt32(546203849)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    break
                case .messageEntityPhone(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1687559349)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCashtag(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1280209983)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityUnderline(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1672577397)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityStrike(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1090087980)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBlockquote(let offset, let length):
                    if boxed {
                        buffer.appendInt32(34469328)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBankCard(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1981704948)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageEntityUnknown(let offset, let length):
                return ("messageEntityUnknown", [("offset", offset), ("length", length)])
                case .messageEntityMention(let offset, let length):
                return ("messageEntityMention", [("offset", offset), ("length", length)])
                case .messageEntityHashtag(let offset, let length):
                return ("messageEntityHashtag", [("offset", offset), ("length", length)])
                case .messageEntityBotCommand(let offset, let length):
                return ("messageEntityBotCommand", [("offset", offset), ("length", length)])
                case .messageEntityUrl(let offset, let length):
                return ("messageEntityUrl", [("offset", offset), ("length", length)])
                case .messageEntityEmail(let offset, let length):
                return ("messageEntityEmail", [("offset", offset), ("length", length)])
                case .messageEntityBold(let offset, let length):
                return ("messageEntityBold", [("offset", offset), ("length", length)])
                case .messageEntityItalic(let offset, let length):
                return ("messageEntityItalic", [("offset", offset), ("length", length)])
                case .messageEntityCode(let offset, let length):
                return ("messageEntityCode", [("offset", offset), ("length", length)])
                case .messageEntityPre(let offset, let length, let language):
                return ("messageEntityPre", [("offset", offset), ("length", length), ("language", language)])
                case .messageEntityTextUrl(let offset, let length, let url):
                return ("messageEntityTextUrl", [("offset", offset), ("length", length), ("url", url)])
                case .messageEntityMentionName(let offset, let length, let userId):
                return ("messageEntityMentionName", [("offset", offset), ("length", length), ("userId", userId)])
                case .inputMessageEntityMentionName(let offset, let length, let userId):
                return ("inputMessageEntityMentionName", [("offset", offset), ("length", length), ("userId", userId)])
                case .messageEntityPhone(let offset, let length):
                return ("messageEntityPhone", [("offset", offset), ("length", length)])
                case .messageEntityCashtag(let offset, let length):
                return ("messageEntityCashtag", [("offset", offset), ("length", length)])
                case .messageEntityUnderline(let offset, let length):
                return ("messageEntityUnderline", [("offset", offset), ("length", length)])
                case .messageEntityStrike(let offset, let length):
                return ("messageEntityStrike", [("offset", offset), ("length", length)])
                case .messageEntityBlockquote(let offset, let length):
                return ("messageEntityBlockquote", [("offset", offset), ("length", length)])
                case .messageEntityBankCard(let offset, let length):
                return ("messageEntityBankCard", [("offset", offset), ("length", length)])
    }
    }
    
        public static func parse_messageEntityUnknown(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityUnknown(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityMention(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityMention(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityHashtag(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityHashtag(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBotCommand(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBotCommand(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityUrl(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityUrl(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityEmail(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityEmail(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBold(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBold(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityItalic(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityItalic(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityCode(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityCode(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityPre(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityPre(offset: _1!, length: _2!, language: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityTextUrl(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityTextUrl(offset: _1!, length: _2!, url: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityMentionName(_ reader: BufferReader) -> MessageEntity? {
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
                return Api.MessageEntity.messageEntityMentionName(offset: _1!, length: _2!, userId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessageEntityMentionName(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.InputUser?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.inputMessageEntityMentionName(offset: _1!, length: _2!, userId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityPhone(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityPhone(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityCashtag(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityCashtag(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityUnderline(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityUnderline(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityStrike(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityStrike(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBlockquote(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBlockquote(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBankCard(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBankCard(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InputPhoto: TypeConstructorDescription {
        case inputPhotoEmpty
        case inputPhoto(id: Int64, accessHash: Int64, fileReference: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(483901197)
                    }
                    
                    break
                case .inputPhoto(let id, let accessHash, let fileReference):
                    if boxed {
                        buffer.appendInt32(1001634122)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhotoEmpty:
                return ("inputPhotoEmpty", [])
                case .inputPhoto(let id, let accessHash, let fileReference):
                return ("inputPhoto", [("id", id), ("accessHash", accessHash), ("fileReference", fileReference)])
    }
    }
    
        public static func parse_inputPhotoEmpty(_ reader: BufferReader) -> InputPhoto? {
            return Api.InputPhoto.inputPhotoEmpty
        }
        public static func parse_inputPhoto(_ reader: BufferReader) -> InputPhoto? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputPhoto.inputPhoto(id: _1!, accessHash: _2!, fileReference: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PageListOrderedItem: TypeConstructorDescription {
        case pageListOrderedItemText(num: String, text: Api.RichText)
        case pageListOrderedItemBlocks(num: String, blocks: [Api.PageBlock])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageListOrderedItemText(let num, let text):
                    if boxed {
                        buffer.appendInt32(1577484359)
                    }
                    serializeString(num, buffer: buffer, boxed: false)
                    text.serialize(buffer, true)
                    break
                case .pageListOrderedItemBlocks(let num, let blocks):
                    if boxed {
                        buffer.appendInt32(-1730311882)
                    }
                    serializeString(num, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocks.count))
                    for item in blocks {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageListOrderedItemText(let num, let text):
                return ("pageListOrderedItemText", [("num", num), ("text", text)])
                case .pageListOrderedItemBlocks(let num, let blocks):
                return ("pageListOrderedItemBlocks", [("num", num), ("blocks", blocks)])
    }
    }
    
        public static func parse_pageListOrderedItemText(_ reader: BufferReader) -> PageListOrderedItem? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageListOrderedItem.pageListOrderedItemText(num: _1!, text: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_pageListOrderedItemBlocks(_ reader: BufferReader) -> PageListOrderedItem? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageListOrderedItem.pageListOrderedItemBlocks(num: _1!, blocks: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum EncryptedChat: TypeConstructorDescription {
        case encryptedChatEmpty(id: Int32)
        case encryptedChatWaiting(id: Int32, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32)
        case encryptedChatRequested(id: Int32, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, gA: Buffer)
        case encryptedChat(id: Int32, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, gAOrB: Buffer, keyFingerprint: Int64)
        case encryptedChatDiscarded(id: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedChatEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-1417756512)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                    if boxed {
                        buffer.appendInt32(1006044124)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    break
                case .encryptedChatRequested(let id, let accessHash, let date, let adminId, let participantId, let gA):
                    if boxed {
                        buffer.appendInt32(-931638658)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    break
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(-94974410)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(adminId, buffer: buffer, boxed: false)
                    serializeInt32(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gAOrB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .encryptedChatDiscarded(let id):
                    if boxed {
                        buffer.appendInt32(332848423)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedChatEmpty(let id):
                return ("encryptedChatEmpty", [("id", id)])
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                return ("encryptedChatWaiting", [("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId)])
                case .encryptedChatRequested(let id, let accessHash, let date, let adminId, let participantId, let gA):
                return ("encryptedChatRequested", [("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId), ("gA", gA)])
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                return ("encryptedChat", [("id", id), ("accessHash", accessHash), ("date", date), ("adminId", adminId), ("participantId", participantId), ("gAOrB", gAOrB), ("keyFingerprint", keyFingerprint)])
                case .encryptedChatDiscarded(let id):
                return ("encryptedChatDiscarded", [("id", id)])
    }
    }
    
        public static func parse_encryptedChatEmpty(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.EncryptedChat.encryptedChatEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatWaiting(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.EncryptedChat.encryptedChatWaiting(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatRequested(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
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
                return Api.EncryptedChat.encryptedChatRequested(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!, gA: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChat(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.EncryptedChat.encryptedChat(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!, gAOrB: _6!, keyFingerprint: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatDiscarded(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.EncryptedChat.encryptedChatDiscarded(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PeerLocated: TypeConstructorDescription {
        case peerLocated(peer: Api.Peer, expires: Int32, distance: Int32)
        case peerSelfLocated(expires: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerLocated(let peer, let expires, let distance):
                    if boxed {
                        buffer.appendInt32(-901375139)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    serializeInt32(distance, buffer: buffer, boxed: false)
                    break
                case .peerSelfLocated(let expires):
                    if boxed {
                        buffer.appendInt32(-118740917)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerLocated(let peer, let expires, let distance):
                return ("peerLocated", [("peer", peer), ("expires", expires), ("distance", distance)])
                case .peerSelfLocated(let expires):
                return ("peerSelfLocated", [("expires", expires)])
    }
    }
    
        public static func parse_peerLocated(_ reader: BufferReader) -> PeerLocated? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PeerLocated.peerLocated(peer: _1!, expires: _2!, distance: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerSelfLocated(_ reader: BufferReader) -> PeerLocated? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.PeerLocated.peerSelfLocated(expires: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Document: TypeConstructorDescription {
        case documentEmpty(id: Int64)
        case document(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, mimeType: String, size: Int32, thumbs: [Api.PhotoSize]?, dcId: Int32, attributes: [Api.DocumentAttribute])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .documentEmpty(let id):
                    if boxed {
                        buffer.appendInt32(922273905)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .document(let flags, let id, let accessHash, let fileReference, let date, let mimeType, let size, let thumbs, let dcId, let attributes):
                    if boxed {
                        buffer.appendInt32(-1683841855)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(thumbs!.count))
                    for item in thumbs! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .documentEmpty(let id):
                return ("documentEmpty", [("id", id)])
                case .document(let flags, let id, let accessHash, let fileReference, let date, let mimeType, let size, let thumbs, let dcId, let attributes):
                return ("document", [("flags", flags), ("id", id), ("accessHash", accessHash), ("fileReference", fileReference), ("date", date), ("mimeType", mimeType), ("size", size), ("thumbs", thumbs), ("dcId", dcId), ("attributes", attributes)])
    }
    }
    
        public static func parse_documentEmpty(_ reader: BufferReader) -> Document? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Document.documentEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_document(_ reader: BufferReader) -> Document? {
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
            var _6: String?
            _6 = parseString(reader)
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: [Api.PhotoSize]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
            } }
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.Document.document(flags: _1!, id: _2!, accessHash: _3!, fileReference: _4!, date: _5!, mimeType: _6!, size: _7!, thumbs: _8, dcId: _9!, attributes: _10!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WebAuthorization: TypeConstructorDescription {
        case webAuthorization(hash: Int64, botId: Int32, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webAuthorization(let hash, let botId, let domain, let browser, let platform, let dateCreated, let dateActive, let ip, let region):
                    if boxed {
                        buffer.appendInt32(-892779534)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    serializeInt32(botId, buffer: buffer, boxed: false)
                    serializeString(domain, buffer: buffer, boxed: false)
                    serializeString(browser, buffer: buffer, boxed: false)
                    serializeString(platform, buffer: buffer, boxed: false)
                    serializeInt32(dateCreated, buffer: buffer, boxed: false)
                    serializeInt32(dateActive, buffer: buffer, boxed: false)
                    serializeString(ip, buffer: buffer, boxed: false)
                    serializeString(region, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webAuthorization(let hash, let botId, let domain, let browser, let platform, let dateCreated, let dateActive, let ip, let region):
                return ("webAuthorization", [("hash", hash), ("botId", botId), ("domain", domain), ("browser", browser), ("platform", platform), ("dateCreated", dateCreated), ("dateActive", dateActive), ("ip", ip), ("region", region)])
    }
    }
    
        public static func parse_webAuthorization(_ reader: BufferReader) -> WebAuthorization? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: String?
            _8 = parseString(reader)
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.WebAuthorization.webAuthorization(hash: _1!, botId: _2!, domain: _3!, browser: _4!, platform: _5!, dateCreated: _6!, dateActive: _7!, ip: _8!, region: _9!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ImportedContact: TypeConstructorDescription {
        case importedContact(userId: Int32, clientId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .importedContact(let userId, let clientId):
                    if boxed {
                        buffer.appendInt32(-805141448)
                    }
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .importedContact(let userId, let clientId):
                return ("importedContact", [("userId", userId), ("clientId", clientId)])
    }
    }
    
        public static func parse_importedContact(_ reader: BufferReader) -> ImportedContact? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ImportedContact.importedContact(userId: _1!, clientId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
