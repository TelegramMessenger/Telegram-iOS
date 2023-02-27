public extension Api {
    indirect enum PageListOrderedItem: TypeConstructorDescription {
        case pageListOrderedItemBlocks(num: String, blocks: [Api.PageBlock])
        case pageListOrderedItemText(num: String, text: Api.RichText)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .pageListOrderedItemText(let num, let text):
                    if boxed {
                        buffer.appendInt32(1577484359)
                    }
                    serializeString(num, buffer: buffer, boxed: false)
                    text.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageListOrderedItemBlocks(let num, let blocks):
                return ("pageListOrderedItemBlocks", [("num", num as Any), ("blocks", blocks as Any)])
                case .pageListOrderedItemText(let num, let text):
                return ("pageListOrderedItemText", [("num", num as Any), ("text", text as Any)])
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
    
    }
}
public extension Api {
    enum PageRelatedArticle: TypeConstructorDescription {
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
                return ("pageRelatedArticle", [("flags", flags as Any), ("url", url as Any), ("webpageId", webpageId as Any), ("title", title as Any), ("description", description as Any), ("photoId", photoId as Any), ("author", author as Any), ("publishedDate", publishedDate as Any)])
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
}
public extension Api {
    indirect enum PageTableCell: TypeConstructorDescription {
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
                return ("pageTableCell", [("flags", flags as Any), ("text", text as Any), ("colspan", colspan as Any), ("rowspan", rowspan as Any)])
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
}
public extension Api {
    enum PageTableRow: TypeConstructorDescription {
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
                return ("pageTableRow", [("cells", cells as Any)])
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
}
public extension Api {
    enum PasswordKdfAlgo: TypeConstructorDescription {
        case passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(salt1: Buffer, salt2: Buffer, g: Int32, p: Buffer)
        case passwordKdfAlgoUnknown
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let salt1, let salt2, let g, let p):
                    if boxed {
                        buffer.appendInt32(982592842)
                    }
                    serializeBytes(salt1, buffer: buffer, boxed: false)
                    serializeBytes(salt2, buffer: buffer, boxed: false)
                    serializeInt32(g, buffer: buffer, boxed: false)
                    serializeBytes(p, buffer: buffer, boxed: false)
                    break
                case .passwordKdfAlgoUnknown:
                    if boxed {
                        buffer.appendInt32(-732254058)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let salt1, let salt2, let g, let p):
                return ("passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow", [("salt1", salt1 as Any), ("salt2", salt2 as Any), ("g", g as Any), ("p", p as Any)])
                case .passwordKdfAlgoUnknown:
                return ("passwordKdfAlgoUnknown", [])
    }
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
        public static func parse_passwordKdfAlgoUnknown(_ reader: BufferReader) -> PasswordKdfAlgo? {
            return Api.PasswordKdfAlgo.passwordKdfAlgoUnknown
        }
    
    }
}
public extension Api {
    enum PaymentCharge: TypeConstructorDescription {
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
                return ("paymentCharge", [("id", id as Any), ("providerChargeId", providerChargeId as Any)])
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
}
public extension Api {
    enum PaymentFormMethod: TypeConstructorDescription {
        case paymentFormMethod(url: String, title: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentFormMethod(let url, let title):
                    if boxed {
                        buffer.appendInt32(-1996951013)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentFormMethod(let url, let title):
                return ("paymentFormMethod", [("url", url as Any), ("title", title as Any)])
    }
    }
    
        public static func parse_paymentFormMethod(_ reader: BufferReader) -> PaymentFormMethod? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PaymentFormMethod.paymentFormMethod(url: _1!, title: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PaymentRequestedInfo: TypeConstructorDescription {
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
                return ("paymentRequestedInfo", [("flags", flags as Any), ("name", name as Any), ("phone", phone as Any), ("email", email as Any), ("shippingAddress", shippingAddress as Any)])
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
}
public extension Api {
    enum PaymentSavedCredentials: TypeConstructorDescription {
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
                return ("paymentSavedCredentialsCard", [("id", id as Any), ("title", title as Any)])
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
}
public extension Api {
    enum Peer: TypeConstructorDescription {
        case peerChannel(channelId: Int64)
        case peerChat(chatId: Int64)
        case peerUser(userId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerChannel(let channelId):
                    if boxed {
                        buffer.appendInt32(-1566230754)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
                case .peerChat(let chatId):
                    if boxed {
                        buffer.appendInt32(918946202)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .peerUser(let userId):
                    if boxed {
                        buffer.appendInt32(1498486562)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerChannel(let channelId):
                return ("peerChannel", [("channelId", channelId as Any)])
                case .peerChat(let chatId):
                return ("peerChat", [("chatId", chatId as Any)])
                case .peerUser(let userId):
                return ("peerUser", [("userId", userId as Any)])
    }
    }
    
        public static func parse_peerChannel(_ reader: BufferReader) -> Peer? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerChannel(channelId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerChat(_ reader: BufferReader) -> Peer? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerUser(_ reader: BufferReader) -> Peer? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerUser(userId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PeerBlocked: TypeConstructorDescription {
        case peerBlocked(peerId: Api.Peer, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerBlocked(let peerId, let date):
                    if boxed {
                        buffer.appendInt32(-386039788)
                    }
                    peerId.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerBlocked(let peerId, let date):
                return ("peerBlocked", [("peerId", peerId as Any), ("date", date as Any)])
    }
    }
    
        public static func parse_peerBlocked(_ reader: BufferReader) -> PeerBlocked? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PeerBlocked.peerBlocked(peerId: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PeerLocated: TypeConstructorDescription {
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
                return ("peerLocated", [("peer", peer as Any), ("expires", expires as Any), ("distance", distance as Any)])
                case .peerSelfLocated(let expires):
                return ("peerSelfLocated", [("expires", expires as Any)])
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
}
public extension Api {
    enum PeerNotifySettings: TypeConstructorDescription {
        case peerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, iosSound: Api.NotificationSound?, androidSound: Api.NotificationSound?, otherSound: Api.NotificationSound?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let iosSound, let androidSound, let otherSound):
                    if boxed {
                        buffer.appendInt32(-1472527322)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {showPreviews!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {silent!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(muteUntil!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {iosSound!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {androidSound!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {otherSound!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let iosSound, let androidSound, let otherSound):
                return ("peerNotifySettings", [("flags", flags as Any), ("showPreviews", showPreviews as Any), ("silent", silent as Any), ("muteUntil", muteUntil as Any), ("iosSound", iosSound as Any), ("androidSound", androidSound as Any), ("otherSound", otherSound as Any)])
    }
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
            var _5: Api.NotificationSound?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            } }
            var _6: Api.NotificationSound?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            } }
            var _7: Api.NotificationSound?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PeerNotifySettings.peerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, iosSound: _5, androidSound: _6, otherSound: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PeerSettings: TypeConstructorDescription {
        case peerSettings(flags: Int32, geoDistance: Int32?, requestChatTitle: String?, requestChatDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerSettings(let flags, let geoDistance, let requestChatTitle, let requestChatDate):
                    if boxed {
                        buffer.appendInt32(-1525149427)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(geoDistance!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeString(requestChatTitle!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(requestChatDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerSettings(let flags, let geoDistance, let requestChatTitle, let requestChatDate):
                return ("peerSettings", [("flags", flags as Any), ("geoDistance", geoDistance as Any), ("requestChatTitle", requestChatTitle as Any), ("requestChatDate", requestChatDate as Any)])
    }
    }
    
        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_2 = reader.readInt32() }
            var _3: String?
            if Int(_1!) & Int(1 << 9) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 6) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 9) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 9) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PeerSettings.peerSettings(flags: _1!, geoDistance: _2, requestChatTitle: _3, requestChatDate: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PhoneCall: TypeConstructorDescription {
        case phoneCall(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64, protocol: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32)
        case phoneCallAccepted(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gB: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallDiscarded(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case phoneCallEmpty(id: Int64)
        case phoneCallRequested(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAHash: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallWaiting(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, protocol: Api.PhoneCallProtocol, receiveDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCall(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint, let `protocol`, let connections, let startDate):
                    if boxed {
                        buffer.appendInt32(-1770029977)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
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
                case .phoneCallAccepted(let flags, let id, let accessHash, let date, let adminId, let participantId, let gB, let `protocol`):
                    if boxed {
                        buffer.appendInt32(912311057)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
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
                case .phoneCallEmpty(let id):
                    if boxed {
                        buffer.appendInt32(1399245077)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .phoneCallRequested(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAHash, let `protocol`):
                    if boxed {
                        buffer.appendInt32(347139340)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gAHash, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    break
                case .phoneCallWaiting(let flags, let id, let accessHash, let date, let adminId, let participantId, let `protocol`, let receiveDate):
                    if boxed {
                        buffer.appendInt32(-987599081)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(receiveDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCall(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint, let `protocol`, let connections, let startDate):
                return ("phoneCall", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gAOrB", gAOrB as Any), ("keyFingerprint", keyFingerprint as Any), ("`protocol`", `protocol` as Any), ("connections", connections as Any), ("startDate", startDate as Any)])
                case .phoneCallAccepted(let flags, let id, let accessHash, let date, let adminId, let participantId, let gB, let `protocol`):
                return ("phoneCallAccepted", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gB", gB as Any), ("`protocol`", `protocol` as Any)])
                case .phoneCallDiscarded(let flags, let id, let reason, let duration):
                return ("phoneCallDiscarded", [("flags", flags as Any), ("id", id as Any), ("reason", reason as Any), ("duration", duration as Any)])
                case .phoneCallEmpty(let id):
                return ("phoneCallEmpty", [("id", id as Any)])
                case .phoneCallRequested(let flags, let id, let accessHash, let date, let adminId, let participantId, let gAHash, let `protocol`):
                return ("phoneCallRequested", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gAHash", gAHash as Any), ("`protocol`", `protocol` as Any)])
                case .phoneCallWaiting(let flags, let id, let accessHash, let date, let adminId, let participantId, let `protocol`, let receiveDate):
                return ("phoneCallWaiting", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("`protocol`", `protocol` as Any), ("receiveDate", receiveDate as Any)])
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
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            _6 = reader.readInt64()
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
        public static func parse_phoneCallAccepted(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            _6 = reader.readInt64()
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
        public static func parse_phoneCallRequested(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            _6 = reader.readInt64()
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
        public static func parse_phoneCallWaiting(_ reader: BufferReader) -> PhoneCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            _6 = reader.readInt64()
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
    
    }
}
public extension Api {
    enum PhoneCallDiscardReason: TypeConstructorDescription {
        case phoneCallDiscardReasonBusy
        case phoneCallDiscardReasonDisconnect
        case phoneCallDiscardReasonHangup
        case phoneCallDiscardReasonMissed
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
