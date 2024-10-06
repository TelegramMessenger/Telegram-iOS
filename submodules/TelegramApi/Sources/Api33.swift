public extension Api.messages {
    enum SponsoredMessages: TypeConstructorDescription {
        case sponsoredMessages(flags: Int32, postsBetween: Int32?, messages: [Api.SponsoredMessage], chats: [Api.Chat], users: [Api.User])
        case sponsoredMessagesEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessages(let flags, let postsBetween, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-907141753)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(postsBetween!, buffer: buffer, boxed: false)}
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
                case .sponsoredMessagesEmpty:
                    if boxed {
                        buffer.appendInt32(406407439)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessages(let flags, let postsBetween, let messages, let chats, let users):
                return ("sponsoredMessages", [("flags", flags as Any), ("postsBetween", postsBetween as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
                case .sponsoredMessagesEmpty:
                return ("sponsoredMessagesEmpty", [])
    }
    }
    
        public static func parse_sponsoredMessages(_ reader: BufferReader) -> SponsoredMessages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: [Api.SponsoredMessage]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SponsoredMessage.self)
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
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.SponsoredMessages.sponsoredMessages(flags: _1!, postsBetween: _2, messages: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_sponsoredMessagesEmpty(_ reader: BufferReader) -> SponsoredMessages? {
            return Api.messages.SponsoredMessages.sponsoredMessagesEmpty
        }
    
    }
}
public extension Api.messages {
    enum StickerSet: TypeConstructorDescription {
        case stickerSet(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document])
        case stickerSetNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSet(let set, let packs, let keywords, let documents):
                    if boxed {
                        buffer.appendInt32(1846886166)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keywords.count))
                    for item in keywords {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetNotModified:
                    if boxed {
                        buffer.appendInt32(-738646805)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSet(let set, let packs, let keywords, let documents):
                return ("stickerSet", [("set", set as Any), ("packs", packs as Any), ("keywords", keywords as Any), ("documents", documents as Any)])
                case .stickerSetNotModified:
                return ("stickerSetNotModified", [])
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
            var _3: [Api.StickerKeyword]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerKeyword.self)
            }
            var _4: [Api.Document]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.StickerSet.stickerSet(set: _1!, packs: _2!, keywords: _3!, documents: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetNotModified(_ reader: BufferReader) -> StickerSet? {
            return Api.messages.StickerSet.stickerSetNotModified
        }
    
    }
}
public extension Api.messages {
    enum StickerSetInstallResult: TypeConstructorDescription {
        case stickerSetInstallResultArchive(sets: [Api.StickerSetCovered])
        case stickerSetInstallResultSuccess
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .stickerSetInstallResultSuccess:
                    if boxed {
                        buffer.appendInt32(946083368)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSetInstallResultArchive(let sets):
                return ("stickerSetInstallResultArchive", [("sets", sets as Any)])
                case .stickerSetInstallResultSuccess:
                return ("stickerSetInstallResultSuccess", [])
    }
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
        public static func parse_stickerSetInstallResultSuccess(_ reader: BufferReader) -> StickerSetInstallResult? {
            return Api.messages.StickerSetInstallResult.stickerSetInstallResultSuccess
        }
    
    }
}
public extension Api.messages {
    enum Stickers: TypeConstructorDescription {
        case stickers(hash: Int64, stickers: [Api.Document])
        case stickersNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickers(let hash, let stickers):
                    if boxed {
                        buffer.appendInt32(816245886)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickersNotModified:
                    if boxed {
                        buffer.appendInt32(-244016606)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickers(let hash, let stickers):
                return ("stickers", [("hash", hash as Any), ("stickers", stickers as Any)])
                case .stickersNotModified:
                return ("stickersNotModified", [])
    }
    }
    
        public static func parse_stickers(_ reader: BufferReader) -> Stickers? {
            var _1: Int64?
            _1 = reader.readInt64()
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
        public static func parse_stickersNotModified(_ reader: BufferReader) -> Stickers? {
            return Api.messages.Stickers.stickersNotModified
        }
    
    }
}
public extension Api.messages {
    enum TranscribedAudio: TypeConstructorDescription {
        case transcribedAudio(flags: Int32, transcriptionId: Int64, text: String, trialRemainsNum: Int32?, trialRemainsUntilDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .transcribedAudio(let flags, let transcriptionId, let text, let trialRemainsNum, let trialRemainsUntilDate):
                    if boxed {
                        buffer.appendInt32(-809903785)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(transcriptionId, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(trialRemainsNum!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(trialRemainsUntilDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .transcribedAudio(let flags, let transcriptionId, let text, let trialRemainsNum, let trialRemainsUntilDate):
                return ("transcribedAudio", [("flags", flags as Any), ("transcriptionId", transcriptionId as Any), ("text", text as Any), ("trialRemainsNum", trialRemainsNum as Any), ("trialRemainsUntilDate", trialRemainsUntilDate as Any)])
    }
    }
    
        public static func parse_transcribedAudio(_ reader: BufferReader) -> TranscribedAudio? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.TranscribedAudio.transcribedAudio(flags: _1!, transcriptionId: _2!, text: _3!, trialRemainsNum: _4, trialRemainsUntilDate: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum TranslatedText: TypeConstructorDescription {
        case translateResult(result: [Api.TextWithEntities])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .translateResult(let result):
                    if boxed {
                        buffer.appendInt32(870003448)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(result.count))
                    for item in result {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .translateResult(let result):
                return ("translateResult", [("result", result as Any)])
    }
    }
    
        public static func parse_translateResult(_ reader: BufferReader) -> TranslatedText? {
            var _1: [Api.TextWithEntities]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TextWithEntities.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.TranslatedText.translateResult(result: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum VotesList: TypeConstructorDescription {
        case votesList(flags: Int32, count: Int32, votes: [Api.MessagePeerVote], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .votesList(let flags, let count, let votes, let chats, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(1218005070)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(votes.count))
                    for item in votes {
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
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .votesList(let flags, let count, let votes, let chats, let users, let nextOffset):
                return ("votesList", [("flags", flags as Any), ("count", count as Any), ("votes", votes as Any), ("chats", chats as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_votesList(_ reader: BufferReader) -> VotesList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessagePeerVote]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessagePeerVote.self)
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
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.messages.VotesList.votesList(flags: _1!, count: _2!, votes: _3!, chats: _4!, users: _5!, nextOffset: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum WebPage: TypeConstructorDescription {
        case webPage(webpage: Api.WebPage, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webPage(let webpage, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-44166467)
                    }
                    webpage.serialize(buffer, true)
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
                case .webPage(let webpage, let chats, let users):
                return ("webPage", [("webpage", webpage as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
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
                return Api.messages.WebPage.webPage(webpage: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum BankCardData: TypeConstructorDescription {
        case bankCardData(title: String, openUrls: [Api.BankCardOpenUrl])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .bankCardData(let title, let openUrls):
                    if boxed {
                        buffer.appendInt32(1042605427)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(openUrls.count))
                    for item in openUrls {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .bankCardData(let title, let openUrls):
                return ("bankCardData", [("title", title as Any), ("openUrls", openUrls as Any)])
    }
    }
    
        public static func parse_bankCardData(_ reader: BufferReader) -> BankCardData? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.BankCardOpenUrl]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BankCardOpenUrl.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.payments.BankCardData.bankCardData(title: _1!, openUrls: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum CheckedGiftCode: TypeConstructorDescription {
        case checkedGiftCode(flags: Int32, fromId: Api.Peer?, giveawayMsgId: Int32?, toId: Int64?, date: Int32, months: Int32, usedDate: Int32?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .checkedGiftCode(let flags, let fromId, let giveawayMsgId, let toId, let date, let months, let usedDate, let chats, let users):
                    if boxed {
                        buffer.appendInt32(675942550)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(giveawayMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(toId!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(months, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(usedDate!, buffer: buffer, boxed: false)}
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
                case .checkedGiftCode(let flags, let fromId, let giveawayMsgId, let toId, let date, let months, let usedDate, let chats, let users):
                return ("checkedGiftCode", [("flags", flags as Any), ("fromId", fromId as Any), ("giveawayMsgId", giveawayMsgId as Any), ("toId", toId as Any), ("date", date as Any), ("months", months as Any), ("usedDate", usedDate as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_checkedGiftCode(_ reader: BufferReader) -> CheckedGiftCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_3 = reader.readInt32() }
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt64() }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = reader.readInt32() }
            var _8: [Api.Chat]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.CheckedGiftCode.checkedGiftCode(flags: _1!, fromId: _2, giveawayMsgId: _3, toId: _4, date: _5!, months: _6!, usedDate: _7, chats: _8!, users: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum ExportedInvoice: TypeConstructorDescription {
        case exportedInvoice(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedInvoice(let url):
                    if boxed {
                        buffer.appendInt32(-1362048039)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedInvoice(let url):
                return ("exportedInvoice", [("url", url as Any)])
    }
    }
    
        public static func parse_exportedInvoice(_ reader: BufferReader) -> ExportedInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.ExportedInvoice.exportedInvoice(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum GiveawayInfo: TypeConstructorDescription {
        case giveawayInfo(flags: Int32, startDate: Int32, joinedTooEarlyDate: Int32?, adminDisallowedChatId: Int64?, disallowedCountry: String?)
        case giveawayInfoResults(flags: Int32, startDate: Int32, giftCodeSlug: String?, starsPrize: Int64?, finishDate: Int32, winnersCount: Int32, activatedCount: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .giveawayInfo(let flags, let startDate, let joinedTooEarlyDate, let adminDisallowedChatId, let disallowedCountry):
                    if boxed {
                        buffer.appendInt32(1130879648)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(joinedTooEarlyDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(adminDisallowedChatId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(disallowedCountry!, buffer: buffer, boxed: false)}
                    break
                case .giveawayInfoResults(let flags, let startDate, let giftCodeSlug, let starsPrize, let finishDate, let winnersCount, let activatedCount):
                    if boxed {
                        buffer.appendInt32(-512366993)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(giftCodeSlug!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(starsPrize!, buffer: buffer, boxed: false)}
                    serializeInt32(finishDate, buffer: buffer, boxed: false)
                    serializeInt32(winnersCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(activatedCount!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .giveawayInfo(let flags, let startDate, let joinedTooEarlyDate, let adminDisallowedChatId, let disallowedCountry):
                return ("giveawayInfo", [("flags", flags as Any), ("startDate", startDate as Any), ("joinedTooEarlyDate", joinedTooEarlyDate as Any), ("adminDisallowedChatId", adminDisallowedChatId as Any), ("disallowedCountry", disallowedCountry as Any)])
                case .giveawayInfoResults(let flags, let startDate, let giftCodeSlug, let starsPrize, let finishDate, let winnersCount, let activatedCount):
                return ("giveawayInfoResults", [("flags", flags as Any), ("startDate", startDate as Any), ("giftCodeSlug", giftCodeSlug as Any), ("starsPrize", starsPrize as Any), ("finishDate", finishDate as Any), ("winnersCount", winnersCount as Any), ("activatedCount", activatedCount as Any)])
    }
    }
    
        public static func parse_giveawayInfo(_ reader: BufferReader) -> GiveawayInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt64() }
            var _5: String?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.payments.GiveawayInfo.giveawayInfo(flags: _1!, startDate: _2!, joinedTooEarlyDate: _3, adminDisallowedChatId: _4, disallowedCountry: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_giveawayInfoResults(_ reader: BufferReader) -> GiveawayInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            if Int(_1!) & Int(1 << 3) != 0 {_3 = parseString(reader) }
            var _4: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_4 = reader.readInt64() }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.payments.GiveawayInfo.giveawayInfoResults(flags: _1!, startDate: _2!, giftCodeSlug: _3, starsPrize: _4, finishDate: _5!, winnersCount: _6!, activatedCount: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum PaymentForm: TypeConstructorDescription {
        case paymentForm(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, providerId: Int64, url: String, nativeProvider: String?, nativeParams: Api.DataJSON?, additionalMethods: [Api.PaymentFormMethod]?, savedInfo: Api.PaymentRequestedInfo?, savedCredentials: [Api.PaymentSavedCredentials]?, users: [Api.User])
        case paymentFormStarGift(formId: Int64, invoice: Api.Invoice)
        case paymentFormStars(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentForm(let flags, let formId, let botId, let title, let description, let photo, let invoice, let providerId, let url, let nativeProvider, let nativeParams, let additionalMethods, let savedInfo, let savedCredentials, let users):
                    if boxed {
                        buffer.appendInt32(-1610250415)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(formId, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeInt64(providerId, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(nativeProvider!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {nativeParams!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(additionalMethods!.count))
                    for item in additionalMethods! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 0) != 0 {savedInfo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(savedCredentials!.count))
                    for item in savedCredentials! {
                        item.serialize(buffer, true)
                    }}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .paymentFormStarGift(let formId, let invoice):
                    if boxed {
                        buffer.appendInt32(-1272590367)
                    }
                    serializeInt64(formId, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    break
                case .paymentFormStars(let flags, let formId, let botId, let title, let description, let photo, let invoice, let users):
                    if boxed {
                        buffer.appendInt32(2079764828)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(formId, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
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
                case .paymentForm(let flags, let formId, let botId, let title, let description, let photo, let invoice, let providerId, let url, let nativeProvider, let nativeParams, let additionalMethods, let savedInfo, let savedCredentials, let users):
                return ("paymentForm", [("flags", flags as Any), ("formId", formId as Any), ("botId", botId as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("providerId", providerId as Any), ("url", url as Any), ("nativeProvider", nativeProvider as Any), ("nativeParams", nativeParams as Any), ("additionalMethods", additionalMethods as Any), ("savedInfo", savedInfo as Any), ("savedCredentials", savedCredentials as Any), ("users", users as Any)])
                case .paymentFormStarGift(let formId, let invoice):
                return ("paymentFormStarGift", [("formId", formId as Any), ("invoice", invoice as Any)])
                case .paymentFormStars(let flags, let formId, let botId, let title, let description, let photo, let invoice, let users):
                return ("paymentFormStars", [("flags", flags as Any), ("formId", formId as Any), ("botId", botId as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_paymentForm(_ reader: BufferReader) -> PaymentForm? {
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
            var _6: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _7: Api.Invoice?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _8: Int64?
            _8 = reader.readInt64()
            var _9: String?
            _9 = parseString(reader)
            var _10: String?
            if Int(_1!) & Int(1 << 4) != 0 {_10 = parseString(reader) }
            var _11: Api.DataJSON?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.DataJSON
            } }
            var _12: [Api.PaymentFormMethod]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PaymentFormMethod.self)
            } }
            var _13: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _14: [Api.PaymentSavedCredentials]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PaymentSavedCredentials.self)
            } }
            var _15: [Api.User]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 5) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 4) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 4) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 6) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 0) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 1) == 0) || _14 != nil
            let _c15 = _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.payments.PaymentForm.paymentForm(flags: _1!, formId: _2!, botId: _3!, title: _4!, description: _5!, photo: _6, invoice: _7!, providerId: _8!, url: _9!, nativeProvider: _10, nativeParams: _11, additionalMethods: _12, savedInfo: _13, savedCredentials: _14, users: _15!)
            }
            else {
                return nil
            }
        }
        public static func parse_paymentFormStarGift(_ reader: BufferReader) -> PaymentForm? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Invoice?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.payments.PaymentForm.paymentFormStarGift(formId: _1!, invoice: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_paymentFormStars(_ reader: BufferReader) -> PaymentForm? {
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
            var _6: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _7: Api.Invoice?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 5) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.payments.PaymentForm.paymentFormStars(flags: _1!, formId: _2!, botId: _3!, title: _4!, description: _5!, photo: _6, invoice: _7!, users: _8!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum PaymentReceipt: TypeConstructorDescription {
        case paymentReceipt(flags: Int32, date: Int32, botId: Int64, providerId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, tipAmount: Int64?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User])
        case paymentReceiptStars(flags: Int32, date: Int32, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, currency: String, totalAmount: Int64, transactionId: String, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentReceipt(let flags, let date, let botId, let providerId, let title, let description, let photo, let invoice, let info, let shipping, let tipAmount, let currency, let totalAmount, let credentialsTitle, let users):
                    if boxed {
                        buffer.appendInt32(1891958275)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeInt64(providerId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {shipping!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(tipAmount!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeString(credentialsTitle, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .paymentReceiptStars(let flags, let date, let botId, let title, let description, let photo, let invoice, let currency, let totalAmount, let transactionId, let users):
                    if boxed {
                        buffer.appendInt32(-625215430)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeString(transactionId, buffer: buffer, boxed: false)
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
                case .paymentReceipt(let flags, let date, let botId, let providerId, let title, let description, let photo, let invoice, let info, let shipping, let tipAmount, let currency, let totalAmount, let credentialsTitle, let users):
                return ("paymentReceipt", [("flags", flags as Any), ("date", date as Any), ("botId", botId as Any), ("providerId", providerId as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("info", info as Any), ("shipping", shipping as Any), ("tipAmount", tipAmount as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("credentialsTitle", credentialsTitle as Any), ("users", users as Any)])
                case .paymentReceiptStars(let flags, let date, let botId, let title, let description, let photo, let invoice, let currency, let totalAmount, let transactionId, let users):
                return ("paymentReceiptStars", [("flags", flags as Any), ("date", date as Any), ("botId", botId as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("transactionId", transactionId as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_paymentReceipt(_ reader: BufferReader) -> PaymentReceipt? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _8: Api.Invoice?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _9: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _10: Api.ShippingOption?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.ShippingOption
            } }
            var _11: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_11 = reader.readInt64() }
            var _12: String?
            _12 = parseString(reader)
            var _13: Int64?
            _13 = reader.readInt64()
            var _14: String?
            _14 = parseString(reader)
            var _15: [Api.User]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.payments.PaymentReceipt.paymentReceipt(flags: _1!, date: _2!, botId: _3!, providerId: _4!, title: _5!, description: _6!, photo: _7, invoice: _8!, info: _9, shipping: _10, tipAmount: _11, currency: _12!, totalAmount: _13!, credentialsTitle: _14!, users: _15!)
            }
            else {
                return nil
            }
        }
        public static func parse_paymentReceiptStars(_ reader: BufferReader) -> PaymentReceipt? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _7: Api.Invoice?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _8: String?
            _8 = parseString(reader)
            var _9: Int64?
            _9 = reader.readInt64()
            var _10: String?
            _10 = parseString(reader)
            var _11: [Api.User]?
            if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.payments.PaymentReceipt.paymentReceiptStars(flags: _1!, date: _2!, botId: _3!, title: _4!, description: _5!, photo: _6, invoice: _7!, currency: _8!, totalAmount: _9!, transactionId: _10!, users: _11!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    indirect enum PaymentResult: TypeConstructorDescription {
        case paymentResult(updates: Api.Updates)
        case paymentVerificationNeeded(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentResult(let updates):
                    if boxed {
                        buffer.appendInt32(1314881805)
                    }
                    updates.serialize(buffer, true)
                    break
                case .paymentVerificationNeeded(let url):
                    if boxed {
                        buffer.appendInt32(-666824391)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentResult(let updates):
                return ("paymentResult", [("updates", updates as Any)])
                case .paymentVerificationNeeded(let url):
                return ("paymentVerificationNeeded", [("url", url as Any)])
    }
    }
    
        public static func parse_paymentResult(_ reader: BufferReader) -> PaymentResult? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentResult(updates: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_paymentVerificationNeeded(_ reader: BufferReader) -> PaymentResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentVerificationNeeded(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum SavedInfo: TypeConstructorDescription {
        case savedInfo(flags: Int32, savedInfo: Api.PaymentRequestedInfo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedInfo(let flags, let savedInfo):
                    if boxed {
                        buffer.appendInt32(-74456004)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {savedInfo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedInfo(let flags, let savedInfo):
                return ("savedInfo", [("flags", flags as Any), ("savedInfo", savedInfo as Any)])
    }
    }
    
        public static func parse_savedInfo(_ reader: BufferReader) -> SavedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.payments.SavedInfo.savedInfo(flags: _1!, savedInfo: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarGifts: TypeConstructorDescription {
        case starGifts(hash: Int32, gifts: [Api.StarGift])
        case starGiftsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGifts(let hash, let gifts):
                    if boxed {
                        buffer.appendInt32(-1877571094)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    break
                case .starGiftsNotModified:
                    if boxed {
                        buffer.appendInt32(-1551326360)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGifts(let hash, let gifts):
                return ("starGifts", [("hash", hash as Any), ("gifts", gifts as Any)])
                case .starGiftsNotModified:
                return ("starGiftsNotModified", [])
    }
    }
    
        public static func parse_starGifts(_ reader: BufferReader) -> StarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StarGift]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGift.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.payments.StarGifts.starGifts(hash: _1!, gifts: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftsNotModified(_ reader: BufferReader) -> StarGifts? {
            return Api.payments.StarGifts.starGiftsNotModified
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueAdsAccountUrl: TypeConstructorDescription {
        case starsRevenueAdsAccountUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueAdsAccountUrl(let url):
                    if boxed {
                        buffer.appendInt32(961445665)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueAdsAccountUrl(let url):
                return ("starsRevenueAdsAccountUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starsRevenueAdsAccountUrl(_ reader: BufferReader) -> StarsRevenueAdsAccountUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarsRevenueAdsAccountUrl.starsRevenueAdsAccountUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueStats: TypeConstructorDescription {
        case starsRevenueStats(revenueGraph: Api.StatsGraph, status: Api.StarsRevenueStatus, usdRate: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueStats(let revenueGraph, let status, let usdRate):
                    if boxed {
                        buffer.appendInt32(-919881925)
                    }
                    revenueGraph.serialize(buffer, true)
                    status.serialize(buffer, true)
                    serializeDouble(usdRate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueStats(let revenueGraph, let status, let usdRate):
                return ("starsRevenueStats", [("revenueGraph", revenueGraph as Any), ("status", status as Any), ("usdRate", usdRate as Any)])
    }
    }
    
        public static func parse_starsRevenueStats(_ reader: BufferReader) -> StarsRevenueStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StarsRevenueStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsRevenueStatus
            }
            var _3: Double?
            _3 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.StarsRevenueStats.starsRevenueStats(revenueGraph: _1!, status: _2!, usdRate: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueWithdrawalUrl: TypeConstructorDescription {
        case starsRevenueWithdrawalUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueWithdrawalUrl(let url):
                    if boxed {
                        buffer.appendInt32(497778871)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueWithdrawalUrl(let url):
                return ("starsRevenueWithdrawalUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starsRevenueWithdrawalUrl(_ reader: BufferReader) -> StarsRevenueWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarsRevenueWithdrawalUrl.starsRevenueWithdrawalUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarsStatus: TypeConstructorDescription {
        case starsStatus(flags: Int32, balance: Int64, subscriptions: [Api.StarsSubscription]?, subscriptionsNextOffset: String?, subscriptionsMissingBalance: Int64?, history: [Api.StarsTransaction]?, nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsStatus(let flags, let balance, let subscriptions, let subscriptionsNextOffset, let subscriptionsMissingBalance, let history, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1141231252)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(balance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(subscriptions!.count))
                    for item in subscriptions! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(subscriptionsNextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(subscriptionsMissingBalance!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(history!.count))
                    for item in history! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
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
                case .starsStatus(let flags, let balance, let subscriptions, let subscriptionsNextOffset, let subscriptionsMissingBalance, let history, let nextOffset, let chats, let users):
                return ("starsStatus", [("flags", flags as Any), ("balance", balance as Any), ("subscriptions", subscriptions as Any), ("subscriptionsNextOffset", subscriptionsNextOffset as Any), ("subscriptionsMissingBalance", subscriptionsMissingBalance as Any), ("history", history as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_starsStatus(_ reader: BufferReader) -> StarsStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.StarsSubscription]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsSubscription.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt64() }
            var _6: [Api.StarsTransaction]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsTransaction.self)
            } }
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
            var _8: [Api.Chat]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.StarsStatus.starsStatus(flags: _1!, balance: _2!, subscriptions: _3, subscriptionsNextOffset: _4, subscriptionsMissingBalance: _5, history: _6, nextOffset: _7, chats: _8!, users: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum UserStarGifts: TypeConstructorDescription {
        case userStarGifts(flags: Int32, count: Int32, gifts: [Api.UserStarGift], nextOffset: String?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userStarGifts(let flags, let count, let gifts, let nextOffset, let users):
                    if boxed {
                        buffer.appendInt32(1801827607)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
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
                case .userStarGifts(let flags, let count, let gifts, let nextOffset, let users):
                return ("userStarGifts", [("flags", flags as Any), ("count", count as Any), ("gifts", gifts as Any), ("nextOffset", nextOffset as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_userStarGifts(_ reader: BufferReader) -> UserStarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.UserStarGift]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.UserStarGift.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.payments.UserStarGifts.userStarGifts(flags: _1!, count: _2!, gifts: _3!, nextOffset: _4, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
