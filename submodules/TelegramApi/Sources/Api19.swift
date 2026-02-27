public extension Api {
    indirect enum PageCaption: TypeConstructorDescription {
        public class Cons_pageCaption {
            public var text: Api.RichText
            public var credit: Api.RichText
            public init(text: Api.RichText, credit: Api.RichText) {
                self.text = text
                self.credit = credit
            }
        }
        case pageCaption(Cons_pageCaption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageCaption(let _data):
                if boxed {
                    buffer.appendInt32(1869903447)
                }
                _data.text.serialize(buffer, true)
                _data.credit.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pageCaption(let _data):
                return ("pageCaption", [("text", _data.text as Any), ("credit", _data.credit as Any)])
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
                return Api.PageCaption.pageCaption(Cons_pageCaption(text: _1!, credit: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum PageListItem: TypeConstructorDescription {
        public class Cons_pageListItemBlocks {
            public var blocks: [Api.PageBlock]
            public init(blocks: [Api.PageBlock]) {
                self.blocks = blocks
            }
        }
        public class Cons_pageListItemText {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        case pageListItemBlocks(Cons_pageListItemBlocks)
        case pageListItemText(Cons_pageListItemText)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageListItemBlocks(let _data):
                if boxed {
                    buffer.appendInt32(635466748)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                break
            case .pageListItemText(let _data):
                if boxed {
                    buffer.appendInt32(-1188055347)
                }
                _data.text.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pageListItemBlocks(let _data):
                return ("pageListItemBlocks", [("blocks", _data.blocks as Any)])
            case .pageListItemText(let _data):
                return ("pageListItemText", [("text", _data.text as Any)])
            }
        }

        public static func parse_pageListItemBlocks(_ reader: BufferReader) -> PageListItem? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageListItem.pageListItemBlocks(Cons_pageListItemBlocks(blocks: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageListItemText(_ reader: BufferReader) -> PageListItem? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageListItem.pageListItemText(Cons_pageListItemText(text: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum PageListOrderedItem: TypeConstructorDescription {
        public class Cons_pageListOrderedItemBlocks {
            public var num: String
            public var blocks: [Api.PageBlock]
            public init(num: String, blocks: [Api.PageBlock]) {
                self.num = num
                self.blocks = blocks
            }
        }
        public class Cons_pageListOrderedItemText {
            public var num: String
            public var text: Api.RichText
            public init(num: String, text: Api.RichText) {
                self.num = num
                self.text = text
            }
        }
        case pageListOrderedItemBlocks(Cons_pageListOrderedItemBlocks)
        case pageListOrderedItemText(Cons_pageListOrderedItemText)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageListOrderedItemBlocks(let _data):
                if boxed {
                    buffer.appendInt32(-1730311882)
                }
                serializeString(_data.num, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                break
            case .pageListOrderedItemText(let _data):
                if boxed {
                    buffer.appendInt32(1577484359)
                }
                serializeString(_data.num, buffer: buffer, boxed: false)
                _data.text.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pageListOrderedItemBlocks(let _data):
                return ("pageListOrderedItemBlocks", [("num", _data.num as Any), ("blocks", _data.blocks as Any)])
            case .pageListOrderedItemText(let _data):
                return ("pageListOrderedItemText", [("num", _data.num as Any), ("text", _data.text as Any)])
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
                return Api.PageListOrderedItem.pageListOrderedItemBlocks(Cons_pageListOrderedItemBlocks(num: _1!, blocks: _2!))
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
                return Api.PageListOrderedItem.pageListOrderedItemText(Cons_pageListOrderedItemText(num: _1!, text: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PageRelatedArticle: TypeConstructorDescription {
        public class Cons_pageRelatedArticle {
            public var flags: Int32
            public var url: String
            public var webpageId: Int64
            public var title: String?
            public var description: String?
            public var photoId: Int64?
            public var author: String?
            public var publishedDate: Int32?
            public init(flags: Int32, url: String, webpageId: Int64, title: String?, description: String?, photoId: Int64?, author: String?, publishedDate: Int32?) {
                self.flags = flags
                self.url = url
                self.webpageId = webpageId
                self.title = title
                self.description = description
                self.photoId = photoId
                self.author = author
                self.publishedDate = publishedDate
            }
        }
        case pageRelatedArticle(Cons_pageRelatedArticle)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageRelatedArticle(let _data):
                if boxed {
                    buffer.appendInt32(-1282352120)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.webpageId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.photoId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.author!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.publishedDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pageRelatedArticle(let _data):
                return ("pageRelatedArticle", [("flags", _data.flags as Any), ("url", _data.url as Any), ("webpageId", _data.webpageId as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photoId", _data.photoId as Any), ("author", _data.author as Any), ("publishedDate", _data.publishedDate as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
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
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PageRelatedArticle.pageRelatedArticle(Cons_pageRelatedArticle(flags: _1!, url: _2!, webpageId: _3!, title: _4, description: _5, photoId: _6, author: _7, publishedDate: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum PageTableCell: TypeConstructorDescription {
        public class Cons_pageTableCell {
            public var flags: Int32
            public var text: Api.RichText?
            public var colspan: Int32?
            public var rowspan: Int32?
            public init(flags: Int32, text: Api.RichText?, colspan: Int32?, rowspan: Int32?) {
                self.flags = flags
                self.text = text
                self.colspan = colspan
                self.rowspan = rowspan
            }
        }
        case pageTableCell(Cons_pageTableCell)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageTableCell(let _data):
                if boxed {
                    buffer.appendInt32(878078826)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    _data.text!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.colspan!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.rowspan!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pageTableCell(let _data):
                return ("pageTableCell", [("flags", _data.flags as Any), ("text", _data.text as Any), ("colspan", _data.colspan as Any), ("rowspan", _data.rowspan as Any)])
            }
        }

        public static func parse_pageTableCell(_ reader: BufferReader) -> PageTableCell? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.RichText?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.RichText
                }
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 7) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PageTableCell.pageTableCell(Cons_pageTableCell(flags: _1!, text: _2, colspan: _3, rowspan: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PageTableRow: TypeConstructorDescription {
        public class Cons_pageTableRow {
            public var cells: [Api.PageTableCell]
            public init(cells: [Api.PageTableCell]) {
                self.cells = cells
            }
        }
        case pageTableRow(Cons_pageTableRow)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageTableRow(let _data):
                if boxed {
                    buffer.appendInt32(-524237339)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.cells.count))
                for item in _data.cells {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pageTableRow(let _data):
                return ("pageTableRow", [("cells", _data.cells as Any)])
            }
        }

        public static func parse_pageTableRow(_ reader: BufferReader) -> PageTableRow? {
            var _1: [Api.PageTableCell]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageTableCell.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageTableRow.pageTableRow(Cons_pageTableRow(cells: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum PaidReactionPrivacy: TypeConstructorDescription {
        public class Cons_paidReactionPrivacyPeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        case paidReactionPrivacyAnonymous
        case paidReactionPrivacyDefault
        case paidReactionPrivacyPeer(Cons_paidReactionPrivacyPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paidReactionPrivacyAnonymous:
                if boxed {
                    buffer.appendInt32(520887001)
                }
                break
            case .paidReactionPrivacyDefault:
                if boxed {
                    buffer.appendInt32(543872158)
                }
                break
            case .paidReactionPrivacyPeer(let _data):
                if boxed {
                    buffer.appendInt32(-596837136)
                }
                _data.peer.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .paidReactionPrivacyAnonymous:
                return ("paidReactionPrivacyAnonymous", [])
            case .paidReactionPrivacyDefault:
                return ("paidReactionPrivacyDefault", [])
            case .paidReactionPrivacyPeer(let _data):
                return ("paidReactionPrivacyPeer", [("peer", _data.peer as Any)])
            }
        }

        public static func parse_paidReactionPrivacyAnonymous(_ reader: BufferReader) -> PaidReactionPrivacy? {
            return Api.PaidReactionPrivacy.paidReactionPrivacyAnonymous
        }
        public static func parse_paidReactionPrivacyDefault(_ reader: BufferReader) -> PaidReactionPrivacy? {
            return Api.PaidReactionPrivacy.paidReactionPrivacyDefault
        }
        public static func parse_paidReactionPrivacyPeer(_ reader: BufferReader) -> PaidReactionPrivacy? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PaidReactionPrivacy.paidReactionPrivacyPeer(Cons_paidReactionPrivacyPeer(peer: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Passkey: TypeConstructorDescription {
        public class Cons_passkey {
            public var flags: Int32
            public var id: String
            public var name: String
            public var date: Int32
            public var softwareEmojiId: Int64?
            public var lastUsageDate: Int32?
            public init(flags: Int32, id: String, name: String, date: Int32, softwareEmojiId: Int64?, lastUsageDate: Int32?) {
                self.flags = flags
                self.id = id
                self.name = name
                self.date = date
                self.softwareEmojiId = softwareEmojiId
                self.lastUsageDate = lastUsageDate
            }
        }
        case passkey(Cons_passkey)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passkey(let _data):
                if boxed {
                    buffer.appendInt32(-1738457409)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.softwareEmojiId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.lastUsageDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .passkey(let _data):
                return ("passkey", [("flags", _data.flags as Any), ("id", _data.id as Any), ("name", _data.name as Any), ("date", _data.date as Any), ("softwareEmojiId", _data.softwareEmojiId as Any), ("lastUsageDate", _data.lastUsageDate as Any)])
            }
        }

        public static func parse_passkey(_ reader: BufferReader) -> Passkey? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Passkey.passkey(Cons_passkey(flags: _1!, id: _2!, name: _3!, date: _4!, softwareEmojiId: _5, lastUsageDate: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PasswordKdfAlgo: TypeConstructorDescription {
        public class Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow {
            public var salt1: Buffer
            public var salt2: Buffer
            public var g: Int32
            public var p: Buffer
            public init(salt1: Buffer, salt2: Buffer, g: Int32, p: Buffer) {
                self.salt1 = salt1
                self.salt2 = salt2
                self.g = g
                self.p = p
            }
        }
        case passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow)
        case passwordKdfAlgoUnknown

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let _data):
                if boxed {
                    buffer.appendInt32(982592842)
                }
                serializeBytes(_data.salt1, buffer: buffer, boxed: false)
                serializeBytes(_data.salt2, buffer: buffer, boxed: false)
                serializeInt32(_data.g, buffer: buffer, boxed: false)
                serializeBytes(_data.p, buffer: buffer, boxed: false)
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
            case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let _data):
                return ("passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow", [("salt1", _data.salt1 as Any), ("salt2", _data.salt2 as Any), ("g", _data.g as Any), ("p", _data.p as Any)])
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
                return Api.PasswordKdfAlgo.passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(salt1: _1!, salt2: _2!, g: _3!, p: _4!))
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
        public class Cons_paymentCharge {
            public var id: String
            public var providerChargeId: String
            public init(id: String, providerChargeId: String) {
                self.id = id
                self.providerChargeId = providerChargeId
            }
        }
        case paymentCharge(Cons_paymentCharge)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paymentCharge(let _data):
                if boxed {
                    buffer.appendInt32(-368917890)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.providerChargeId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .paymentCharge(let _data):
                return ("paymentCharge", [("id", _data.id as Any), ("providerChargeId", _data.providerChargeId as Any)])
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
                return Api.PaymentCharge.paymentCharge(Cons_paymentCharge(id: _1!, providerChargeId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PaymentFormMethod: TypeConstructorDescription {
        public class Cons_paymentFormMethod {
            public var url: String
            public var title: String
            public init(url: String, title: String) {
                self.url = url
                self.title = title
            }
        }
        case paymentFormMethod(Cons_paymentFormMethod)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paymentFormMethod(let _data):
                if boxed {
                    buffer.appendInt32(-1996951013)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .paymentFormMethod(let _data):
                return ("paymentFormMethod", [("url", _data.url as Any), ("title", _data.title as Any)])
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
                return Api.PaymentFormMethod.paymentFormMethod(Cons_paymentFormMethod(url: _1!, title: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PaymentRequestedInfo: TypeConstructorDescription {
        public class Cons_paymentRequestedInfo {
            public var flags: Int32
            public var name: String?
            public var phone: String?
            public var email: String?
            public var shippingAddress: Api.PostAddress?
            public init(flags: Int32, name: String?, phone: String?, email: String?, shippingAddress: Api.PostAddress?) {
                self.flags = flags
                self.name = name
                self.phone = phone
                self.email = email
                self.shippingAddress = shippingAddress
            }
        }
        case paymentRequestedInfo(Cons_paymentRequestedInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paymentRequestedInfo(let _data):
                if boxed {
                    buffer.appendInt32(-1868808300)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.name!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.phone!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.email!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.shippingAddress!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .paymentRequestedInfo(let _data):
                return ("paymentRequestedInfo", [("flags", _data.flags as Any), ("name", _data.name as Any), ("phone", _data.phone as Any), ("email", _data.email as Any), ("shippingAddress", _data.shippingAddress as Any)])
            }
        }

        public static func parse_paymentRequestedInfo(_ reader: BufferReader) -> PaymentRequestedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseString(reader)
            }
            var _5: Api.PostAddress?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.PostAddress
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PaymentRequestedInfo.paymentRequestedInfo(Cons_paymentRequestedInfo(flags: _1!, name: _2, phone: _3, email: _4, shippingAddress: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PaymentSavedCredentials: TypeConstructorDescription {
        public class Cons_paymentSavedCredentialsCard {
            public var id: String
            public var title: String
            public init(id: String, title: String) {
                self.id = id
                self.title = title
            }
        }
        case paymentSavedCredentialsCard(Cons_paymentSavedCredentialsCard)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paymentSavedCredentialsCard(let _data):
                if boxed {
                    buffer.appendInt32(-842892769)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .paymentSavedCredentialsCard(let _data):
                return ("paymentSavedCredentialsCard", [("id", _data.id as Any), ("title", _data.title as Any)])
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
                return Api.PaymentSavedCredentials.paymentSavedCredentialsCard(Cons_paymentSavedCredentialsCard(id: _1!, title: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Peer: TypeConstructorDescription {
        public class Cons_peerChannel {
            public var channelId: Int64
            public init(channelId: Int64) {
                self.channelId = channelId
            }
        }
        public class Cons_peerChat {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
        }
        public class Cons_peerUser {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
        }
        case peerChannel(Cons_peerChannel)
        case peerChat(Cons_peerChat)
        case peerUser(Cons_peerUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerChannel(let _data):
                if boxed {
                    buffer.appendInt32(-1566230754)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                break
            case .peerChat(let _data):
                if boxed {
                    buffer.appendInt32(918946202)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                break
            case .peerUser(let _data):
                if boxed {
                    buffer.appendInt32(1498486562)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerChannel(let _data):
                return ("peerChannel", [("channelId", _data.channelId as Any)])
            case .peerChat(let _data):
                return ("peerChat", [("chatId", _data.chatId as Any)])
            case .peerUser(let _data):
                return ("peerUser", [("userId", _data.userId as Any)])
            }
        }

        public static func parse_peerChannel(_ reader: BufferReader) -> Peer? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Peer.peerChannel(Cons_peerChannel(channelId: _1!))
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
                return Api.Peer.peerChat(Cons_peerChat(chatId: _1!))
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
                return Api.Peer.peerUser(Cons_peerUser(userId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PeerBlocked: TypeConstructorDescription {
        public class Cons_peerBlocked {
            public var peerId: Api.Peer
            public var date: Int32
            public init(peerId: Api.Peer, date: Int32) {
                self.peerId = peerId
                self.date = date
            }
        }
        case peerBlocked(Cons_peerBlocked)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerBlocked(let _data):
                if boxed {
                    buffer.appendInt32(-386039788)
                }
                _data.peerId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerBlocked(let _data):
                return ("peerBlocked", [("peerId", _data.peerId as Any), ("date", _data.date as Any)])
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
                return Api.PeerBlocked.peerBlocked(Cons_peerBlocked(peerId: _1!, date: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PeerColor: TypeConstructorDescription {
        public class Cons_inputPeerColorCollectible {
            public var collectibleId: Int64
            public init(collectibleId: Int64) {
                self.collectibleId = collectibleId
            }
        }
        public class Cons_peerColor {
            public var flags: Int32
            public var color: Int32?
            public var backgroundEmojiId: Int64?
            public init(flags: Int32, color: Int32?, backgroundEmojiId: Int64?) {
                self.flags = flags
                self.color = color
                self.backgroundEmojiId = backgroundEmojiId
            }
        }
        public class Cons_peerColorCollectible {
            public var flags: Int32
            public var collectibleId: Int64
            public var giftEmojiId: Int64
            public var backgroundEmojiId: Int64
            public var accentColor: Int32
            public var colors: [Int32]
            public var darkAccentColor: Int32?
            public var darkColors: [Int32]?
            public init(flags: Int32, collectibleId: Int64, giftEmojiId: Int64, backgroundEmojiId: Int64, accentColor: Int32, colors: [Int32], darkAccentColor: Int32?, darkColors: [Int32]?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.giftEmojiId = giftEmojiId
                self.backgroundEmojiId = backgroundEmojiId
                self.accentColor = accentColor
                self.colors = colors
                self.darkAccentColor = darkAccentColor
                self.darkColors = darkColors
            }
        }
        case inputPeerColorCollectible(Cons_inputPeerColorCollectible)
        case peerColor(Cons_peerColor)
        case peerColorCollectible(Cons_peerColorCollectible)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPeerColorCollectible(let _data):
                if boxed {
                    buffer.appendInt32(-1192589655)
                }
                serializeInt64(_data.collectibleId, buffer: buffer, boxed: false)
                break
            case .peerColor(let _data):
                if boxed {
                    buffer.appendInt32(-1253352753)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.color!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt64(_data.backgroundEmojiId!, buffer: buffer, boxed: false)
                }
                break
            case .peerColorCollectible(let _data):
                if boxed {
                    buffer.appendInt32(-1178573926)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.collectibleId, buffer: buffer, boxed: false)
                serializeInt64(_data.giftEmojiId, buffer: buffer, boxed: false)
                serializeInt64(_data.backgroundEmojiId, buffer: buffer, boxed: false)
                serializeInt32(_data.accentColor, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.colors.count))
                for item in _data.colors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.darkAccentColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.darkColors!.count))
                    for item in _data.darkColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPeerColorCollectible(let _data):
                return ("inputPeerColorCollectible", [("collectibleId", _data.collectibleId as Any)])
            case .peerColor(let _data):
                return ("peerColor", [("flags", _data.flags as Any), ("color", _data.color as Any), ("backgroundEmojiId", _data.backgroundEmojiId as Any)])
            case .peerColorCollectible(let _data):
                return ("peerColorCollectible", [("flags", _data.flags as Any), ("collectibleId", _data.collectibleId as Any), ("giftEmojiId", _data.giftEmojiId as Any), ("backgroundEmojiId", _data.backgroundEmojiId as Any), ("accentColor", _data.accentColor as Any), ("colors", _data.colors as Any), ("darkAccentColor", _data.darkAccentColor as Any), ("darkColors", _data.darkColors as Any)])
            }
        }

        public static func parse_inputPeerColorCollectible(_ reader: BufferReader) -> PeerColor? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.PeerColor.inputPeerColorCollectible(Cons_inputPeerColorCollectible(collectibleId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_peerColor(_ reader: BufferReader) -> PeerColor? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PeerColor.peerColor(Cons_peerColor(flags: _1!, color: _2, backgroundEmojiId: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_peerColorCollectible(_ reader: BufferReader) -> PeerColor? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Int32]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _7 = reader.readInt32()
            }
            var _8: [Int32]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PeerColor.peerColorCollectible(Cons_peerColorCollectible(flags: _1!, collectibleId: _2!, giftEmojiId: _3!, backgroundEmojiId: _4!, accentColor: _5!, colors: _6!, darkAccentColor: _7, darkColors: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PeerLocated: TypeConstructorDescription {
        public class Cons_peerLocated {
            public var peer: Api.Peer
            public var expires: Int32
            public var distance: Int32
            public init(peer: Api.Peer, expires: Int32, distance: Int32) {
                self.peer = peer
                self.expires = expires
                self.distance = distance
            }
        }
        public class Cons_peerSelfLocated {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        case peerLocated(Cons_peerLocated)
        case peerSelfLocated(Cons_peerSelfLocated)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerLocated(let _data):
                if boxed {
                    buffer.appendInt32(-901375139)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                serializeInt32(_data.distance, buffer: buffer, boxed: false)
                break
            case .peerSelfLocated(let _data):
                if boxed {
                    buffer.appendInt32(-118740917)
                }
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerLocated(let _data):
                return ("peerLocated", [("peer", _data.peer as Any), ("expires", _data.expires as Any), ("distance", _data.distance as Any)])
            case .peerSelfLocated(let _data):
                return ("peerSelfLocated", [("expires", _data.expires as Any)])
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
                return Api.PeerLocated.peerLocated(Cons_peerLocated(peer: _1!, expires: _2!, distance: _3!))
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
                return Api.PeerLocated.peerSelfLocated(Cons_peerSelfLocated(expires: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PeerNotifySettings: TypeConstructorDescription {
        public class Cons_peerNotifySettings {
            public var flags: Int32
            public var showPreviews: Api.Bool?
            public var silent: Api.Bool?
            public var muteUntil: Int32?
            public var iosSound: Api.NotificationSound?
            public var androidSound: Api.NotificationSound?
            public var otherSound: Api.NotificationSound?
            public var storiesMuted: Api.Bool?
            public var storiesHideSender: Api.Bool?
            public var storiesIosSound: Api.NotificationSound?
            public var storiesAndroidSound: Api.NotificationSound?
            public var storiesOtherSound: Api.NotificationSound?
            public init(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, iosSound: Api.NotificationSound?, androidSound: Api.NotificationSound?, otherSound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesIosSound: Api.NotificationSound?, storiesAndroidSound: Api.NotificationSound?, storiesOtherSound: Api.NotificationSound?) {
                self.flags = flags
                self.showPreviews = showPreviews
                self.silent = silent
                self.muteUntil = muteUntil
                self.iosSound = iosSound
                self.androidSound = androidSound
                self.otherSound = otherSound
                self.storiesMuted = storiesMuted
                self.storiesHideSender = storiesHideSender
                self.storiesIosSound = storiesIosSound
                self.storiesAndroidSound = storiesAndroidSound
                self.storiesOtherSound = storiesOtherSound
            }
        }
        case peerNotifySettings(Cons_peerNotifySettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerNotifySettings(let _data):
                if boxed {
                    buffer.appendInt32(-1721619444)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.showPreviews!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.silent!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.muteUntil!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.iosSound!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.androidSound!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.otherSound!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.storiesMuted!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    _data.storiesHideSender!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.storiesIosSound!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.storiesAndroidSound!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.storiesOtherSound!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerNotifySettings(let _data):
                return ("peerNotifySettings", [("flags", _data.flags as Any), ("showPreviews", _data.showPreviews as Any), ("silent", _data.silent as Any), ("muteUntil", _data.muteUntil as Any), ("iosSound", _data.iosSound as Any), ("androidSound", _data.androidSound as Any), ("otherSound", _data.otherSound as Any), ("storiesMuted", _data.storiesMuted as Any), ("storiesHideSender", _data.storiesHideSender as Any), ("storiesIosSound", _data.storiesIosSound as Any), ("storiesAndroidSound", _data.storiesAndroidSound as Any), ("storiesOtherSound", _data.storiesOtherSound as Any)])
            }
        }

        public static func parse_peerNotifySettings(_ reader: BufferReader) -> PeerNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Api.NotificationSound?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _6: Api.NotificationSound?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _7: Api.NotificationSound?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _8: Api.Bool?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _9: Api.Bool?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _10: Api.NotificationSound?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _11: Api.NotificationSound?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _12: Api.NotificationSound?
            if Int(_1!) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 7) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 8) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 9) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 10) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.PeerNotifySettings.peerNotifySettings(Cons_peerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, iosSound: _5, androidSound: _6, otherSound: _7, storiesMuted: _8, storiesHideSender: _9, storiesIosSound: _10, storiesAndroidSound: _11, storiesOtherSound: _12))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PeerSettings: TypeConstructorDescription {
        public class Cons_peerSettings {
            public var flags: Int32
            public var geoDistance: Int32?
            public var requestChatTitle: String?
            public var requestChatDate: Int32?
            public var businessBotId: Int64?
            public var businessBotManageUrl: String?
            public var chargePaidMessageStars: Int64?
            public var registrationMonth: String?
            public var phoneCountry: String?
            public var nameChangeDate: Int32?
            public var photoChangeDate: Int32?
            public init(flags: Int32, geoDistance: Int32?, requestChatTitle: String?, requestChatDate: Int32?, businessBotId: Int64?, businessBotManageUrl: String?, chargePaidMessageStars: Int64?, registrationMonth: String?, phoneCountry: String?, nameChangeDate: Int32?, photoChangeDate: Int32?) {
                self.flags = flags
                self.geoDistance = geoDistance
                self.requestChatTitle = requestChatTitle
                self.requestChatDate = requestChatDate
                self.businessBotId = businessBotId
                self.businessBotManageUrl = businessBotManageUrl
                self.chargePaidMessageStars = chargePaidMessageStars
                self.registrationMonth = registrationMonth
                self.phoneCountry = phoneCountry
                self.nameChangeDate = nameChangeDate
                self.photoChangeDate = photoChangeDate
            }
        }
        case peerSettings(Cons_peerSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerSettings(let _data):
                if boxed {
                    buffer.appendInt32(-193510921)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.geoDistance!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeString(_data.requestChatTitle!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeInt32(_data.requestChatDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt64(_data.businessBotId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeString(_data.businessBotManageUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt64(_data.chargePaidMessageStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeString(_data.registrationMonth!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.phoneCountry!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    serializeInt32(_data.nameChangeDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    serializeInt32(_data.photoChangeDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerSettings(let _data):
                return ("peerSettings", [("flags", _data.flags as Any), ("geoDistance", _data.geoDistance as Any), ("requestChatTitle", _data.requestChatTitle as Any), ("requestChatDate", _data.requestChatDate as Any), ("businessBotId", _data.businessBotId as Any), ("businessBotManageUrl", _data.businessBotManageUrl as Any), ("chargePaidMessageStars", _data.chargePaidMessageStars as Any), ("registrationMonth", _data.registrationMonth as Any), ("phoneCountry", _data.phoneCountry as Any), ("nameChangeDate", _data.nameChangeDate as Any), ("photoChangeDate", _data.photoChangeDate as Any)])
            }
        }

        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _2 = reader.readInt32()
            }
            var _3: String?
            if Int(_1!) & Int(1 << 9) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int64?
            if Int(_1!) & Int(1 << 13) != 0 {
                _5 = reader.readInt64()
            }
            var _6: String?
            if Int(_1!) & Int(1 << 13) != 0 {
                _6 = parseString(reader)
            }
            var _7: Int64?
            if Int(_1!) & Int(1 << 14) != 0 {
                _7 = reader.readInt64()
            }
            var _8: String?
            if Int(_1!) & Int(1 << 15) != 0 {
                _8 = parseString(reader)
            }
            var _9: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _9 = parseString(reader)
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Int32?
            if Int(_1!) & Int(1 << 18) != 0 {
                _11 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 6) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 9) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 9) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 13) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 13) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 14) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 15) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 16) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 17) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 18) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.PeerSettings.peerSettings(Cons_peerSettings(flags: _1!, geoDistance: _2, requestChatTitle: _3, requestChatDate: _4, businessBotId: _5, businessBotManageUrl: _6, chargePaidMessageStars: _7, registrationMonth: _8, phoneCountry: _9, nameChangeDate: _10, photoChangeDate: _11))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PeerStories: TypeConstructorDescription {
        public class Cons_peerStories {
            public var flags: Int32
            public var peer: Api.Peer
            public var maxReadId: Int32?
            public var stories: [Api.StoryItem]
            public init(flags: Int32, peer: Api.Peer, maxReadId: Int32?, stories: [Api.StoryItem]) {
                self.flags = flags
                self.peer = peer
                self.maxReadId = maxReadId
                self.stories = stories
            }
        }
        case peerStories(Cons_peerStories)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerStories(let _data):
                if boxed {
                    buffer.appendInt32(-1707742823)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.maxReadId!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stories.count))
                for item in _data.stories {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerStories(let _data):
                return ("peerStories", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("maxReadId", _data.maxReadId as Any), ("stories", _data.stories as Any)])
            }
        }

        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: [Api.StoryItem]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryItem.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PeerStories.peerStories(Cons_peerStories(flags: _1!, peer: _2!, maxReadId: _3, stories: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PendingSuggestion: TypeConstructorDescription {
        public class Cons_pendingSuggestion {
            public var suggestion: String
            public var title: Api.TextWithEntities
            public var description: Api.TextWithEntities
            public var url: String
            public init(suggestion: String, title: Api.TextWithEntities, description: Api.TextWithEntities, url: String) {
                self.suggestion = suggestion
                self.title = title
                self.description = description
                self.url = url
            }
        }
        case pendingSuggestion(Cons_pendingSuggestion)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pendingSuggestion(let _data):
                if boxed {
                    buffer.appendInt32(-404214254)
                }
                serializeString(_data.suggestion, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                _data.description.serialize(buffer, true)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .pendingSuggestion(let _data):
                return ("pendingSuggestion", [("suggestion", _data.suggestion as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("url", _data.url as Any)])
            }
        }

        public static func parse_pendingSuggestion(_ reader: BufferReader) -> PendingSuggestion? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _3: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PendingSuggestion.pendingSuggestion(Cons_pendingSuggestion(suggestion: _1!, title: _2!, description: _3!, url: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum PhoneCall: TypeConstructorDescription {
        public class Cons_phoneCall {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gAOrB: Buffer
            public var keyFingerprint: Int64
            public var `protocol`: Api.PhoneCallProtocol
            public var connections: [Api.PhoneConnection]
            public var startDate: Int32
            public var customParameters: Api.DataJSON?
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32, customParameters: Api.DataJSON?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gAOrB = gAOrB
                self.keyFingerprint = keyFingerprint
                self.`protocol` = `protocol`
                self.connections = connections
                self.startDate = startDate
                self.customParameters = customParameters
            }
        }
        public class Cons_phoneCallAccepted {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gB: Buffer
            public var `protocol`: Api.PhoneCallProtocol
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gB: Buffer, `protocol`: Api.PhoneCallProtocol) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gB = gB
                self.`protocol` = `protocol`
            }
        }
        public class Cons_phoneCallDiscarded {
            public var flags: Int32
            public var id: Int64
            public var reason: Api.PhoneCallDiscardReason?
            public var duration: Int32?
            public init(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?) {
                self.flags = flags
                self.id = id
                self.reason = reason
                self.duration = duration
            }
        }
        public class Cons_phoneCallEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        public class Cons_phoneCallRequested {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gAHash: Buffer
            public var `protocol`: Api.PhoneCallProtocol
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gAHash = gAHash
                self.`protocol` = `protocol`
            }
        }
        public class Cons_phoneCallWaiting {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var `protocol`: Api.PhoneCallProtocol
            public var receiveDate: Int32?
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, `protocol`: Api.PhoneCallProtocol, receiveDate: Int32?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.`protocol` = `protocol`
                self.receiveDate = receiveDate
            }
        }
        case phoneCall(Cons_phoneCall)
        case phoneCallAccepted(Cons_phoneCallAccepted)
        case phoneCallDiscarded(Cons_phoneCallDiscarded)
        case phoneCallEmpty(Cons_phoneCallEmpty)
        case phoneCallRequested(Cons_phoneCallRequested)
        case phoneCallWaiting(Cons_phoneCallWaiting)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .phoneCall(let _data):
                if boxed {
                    buffer.appendInt32(810769141)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                serializeBytes(_data.gAOrB, buffer: buffer, boxed: false)
                serializeInt64(_data.keyFingerprint, buffer: buffer, boxed: false)
                _data.`protocol`.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.connections.count))
                for item in _data.connections {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.startDate, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    _data.customParameters!.serialize(buffer, true)
                }
                break
            case .phoneCallAccepted(let _data):
                if boxed {
                    buffer.appendInt32(912311057)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                serializeBytes(_data.gB, buffer: buffer, boxed: false)
                _data.`protocol`.serialize(buffer, true)
                break
            case .phoneCallDiscarded(let _data):
                if boxed {
                    buffer.appendInt32(1355435489)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.reason!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.duration!, buffer: buffer, boxed: false)
                }
                break
            case .phoneCallEmpty(let _data):
                if boxed {
                    buffer.appendInt32(1399245077)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            case .phoneCallRequested(let _data):
                if boxed {
                    buffer.appendInt32(347139340)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                serializeBytes(_data.gAHash, buffer: buffer, boxed: false)
                _data.`protocol`.serialize(buffer, true)
                break
            case .phoneCallWaiting(let _data):
                if boxed {
                    buffer.appendInt32(-987599081)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                _data.`protocol`.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.receiveDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .phoneCall(let _data):
                return ("phoneCall", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any), ("gAOrB", _data.gAOrB as Any), ("keyFingerprint", _data.keyFingerprint as Any), ("`protocol`", _data.`protocol` as Any), ("connections", _data.connections as Any), ("startDate", _data.startDate as Any), ("customParameters", _data.customParameters as Any)])
            case .phoneCallAccepted(let _data):
                return ("phoneCallAccepted", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any), ("gB", _data.gB as Any), ("`protocol`", _data.`protocol` as Any)])
            case .phoneCallDiscarded(let _data):
                return ("phoneCallDiscarded", [("flags", _data.flags as Any), ("id", _data.id as Any), ("reason", _data.reason as Any), ("duration", _data.duration as Any)])
            case .phoneCallEmpty(let _data):
                return ("phoneCallEmpty", [("id", _data.id as Any)])
            case .phoneCallRequested(let _data):
                return ("phoneCallRequested", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any), ("gAHash", _data.gAHash as Any), ("`protocol`", _data.`protocol` as Any)])
            case .phoneCallWaiting(let _data):
                return ("phoneCallWaiting", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any), ("`protocol`", _data.`protocol` as Any), ("receiveDate", _data.receiveDate as Any)])
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
            var _12: Api.DataJSON?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.DataJSON
                }
            }
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
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.PhoneCall.phoneCall(Cons_phoneCall(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, gAOrB: _7!, keyFingerprint: _8!, protocol: _9!, connections: _10!, startDate: _11!, customParameters: _12))
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
                return Api.PhoneCall.phoneCallAccepted(Cons_phoneCallAccepted(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, gB: _7!, protocol: _8!))
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
                return Api.PhoneCall.phoneCallDiscarded(Cons_phoneCallDiscarded(flags: _1!, id: _2!, reason: _3, duration: _4))
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
                return Api.PhoneCall.phoneCallEmpty(Cons_phoneCallEmpty(id: _1!))
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
                return Api.PhoneCall.phoneCallRequested(Cons_phoneCallRequested(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, gAHash: _7!, protocol: _8!))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _8 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.PhoneCall.phoneCallWaiting(Cons_phoneCallWaiting(flags: _1!, id: _2!, accessHash: _3!, date: _4!, adminId: _5!, participantId: _6!, protocol: _7!, receiveDate: _8))
            }
            else {
                return nil
            }
        }
    }
}
