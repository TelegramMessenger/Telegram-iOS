public extension Api {
    enum ShippingOption: TypeConstructorDescription {
        public class Cons_shippingOption {
            public var id: String
            public var title: String
            public var prices: [Api.LabeledPrice]
            public init(id: String, title: String, prices: [Api.LabeledPrice]) {
                self.id = id
                self.title = title
                self.prices = prices
            }
        }
        case shippingOption(Cons_shippingOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .shippingOption(let _data):
                if boxed {
                    buffer.appendInt32(-1239335713)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.prices.count))
                for item in _data.prices {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .shippingOption(let _data):
                return ("shippingOption", [("id", _data.id as Any), ("title", _data.title as Any), ("prices", _data.prices as Any)])
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
                return Api.ShippingOption.shippingOption(Cons_shippingOption(id: _1!, title: _2!, prices: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SmsJob: TypeConstructorDescription {
        public class Cons_smsJob {
            public var jobId: String
            public var phoneNumber: String
            public var text: String
            public init(jobId: String, phoneNumber: String, text: String) {
                self.jobId = jobId
                self.phoneNumber = phoneNumber
                self.text = text
            }
        }
        case smsJob(Cons_smsJob)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .smsJob(let _data):
                if boxed {
                    buffer.appendInt32(-425595208)
                }
                serializeString(_data.jobId, buffer: buffer, boxed: false)
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .smsJob(let _data):
                return ("smsJob", [("jobId", _data.jobId as Any), ("phoneNumber", _data.phoneNumber as Any), ("text", _data.text as Any)])
            }
        }

        public static func parse_smsJob(_ reader: BufferReader) -> SmsJob? {
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
                return Api.SmsJob.smsJob(Cons_smsJob(jobId: _1!, phoneNumber: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        public class Cons_sponsoredMessage {
            public var flags: Int32
            public var randomId: Buffer
            public var url: String
            public var title: String
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var photo: Api.Photo?
            public var media: Api.MessageMedia?
            public var color: Api.PeerColor?
            public var buttonText: String
            public var sponsorInfo: String?
            public var additionalInfo: String?
            public var minDisplayDuration: Int32?
            public var maxDisplayDuration: Int32?
            public init(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?, minDisplayDuration: Int32?, maxDisplayDuration: Int32?) {
                self.flags = flags
                self.randomId = randomId
                self.url = url
                self.title = title
                self.message = message
                self.entities = entities
                self.photo = photo
                self.media = media
                self.color = color
                self.buttonText = buttonText
                self.sponsorInfo = sponsorInfo
                self.additionalInfo = additionalInfo
                self.minDisplayDuration = minDisplayDuration
                self.maxDisplayDuration = maxDisplayDuration
            }
        }
        case sponsoredMessage(Cons_sponsoredMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredMessage(let _data):
                if boxed {
                    buffer.appendInt32(2109703795)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.randomId, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.media!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    _data.color!.serialize(buffer, true)
                }
                serializeString(_data.buttonText, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeString(_data.sponsorInfo!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.additionalInfo!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.minDisplayDuration!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.maxDisplayDuration!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sponsoredMessage(let _data):
                return ("sponsoredMessage", [("flags", _data.flags as Any), ("randomId", _data.randomId as Any), ("url", _data.url as Any), ("title", _data.title as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("photo", _data.photo as Any), ("media", _data.media as Any), ("color", _data.color as Any), ("buttonText", _data.buttonText as Any), ("sponsorInfo", _data.sponsorInfo as Any), ("additionalInfo", _data.additionalInfo as Any), ("minDisplayDuration", _data.minDisplayDuration as Any), ("maxDisplayDuration", _data.maxDisplayDuration as Any)])
            }
        }

        public static func parse_sponsoredMessage(_ reader: BufferReader) -> SponsoredMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _7: Api.Photo?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _8: Api.MessageMedia?
            if Int(_1!) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            var _9: Api.PeerColor?
            if Int(_1!) & Int(1 << 13) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _10: String?
            _10 = parseString(reader)
            var _11: String?
            if Int(_1!) & Int(1 << 7) != 0 {
                _11 = parseString(reader)
            }
            var _12: String?
            if Int(_1!) & Int(1 << 8) != 0 {
                _12 = parseString(reader)
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {
                _13 = reader.readInt32()
            }
            var _14: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {
                _14 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 14) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 13) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 8) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 15) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 15) == 0) || _14 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.SponsoredMessage.sponsoredMessage(Cons_sponsoredMessage(flags: _1!, randomId: _2!, url: _3!, title: _4!, message: _5!, entities: _6, photo: _7, media: _8, color: _9, buttonText: _10!, sponsorInfo: _11, additionalInfo: _12, minDisplayDuration: _13, maxDisplayDuration: _14))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SponsoredMessageReportOption: TypeConstructorDescription {
        public class Cons_sponsoredMessageReportOption {
            public var text: String
            public var option: Buffer
            public init(text: String, option: Buffer) {
                self.text = text
                self.option = option
            }
        }
        case sponsoredMessageReportOption(Cons_sponsoredMessageReportOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredMessageReportOption(let _data):
                if boxed {
                    buffer.appendInt32(1124938064)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeBytes(_data.option, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sponsoredMessageReportOption(let _data):
                return ("sponsoredMessageReportOption", [("text", _data.text as Any), ("option", _data.option as Any)])
            }
        }

        public static func parse_sponsoredMessageReportOption(_ reader: BufferReader) -> SponsoredMessageReportOption? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SponsoredMessageReportOption.sponsoredMessageReportOption(Cons_sponsoredMessageReportOption(text: _1!, option: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SponsoredPeer: TypeConstructorDescription {
        public class Cons_sponsoredPeer {
            public var flags: Int32
            public var randomId: Buffer
            public var peer: Api.Peer
            public var sponsorInfo: String?
            public var additionalInfo: String?
            public init(flags: Int32, randomId: Buffer, peer: Api.Peer, sponsorInfo: String?, additionalInfo: String?) {
                self.flags = flags
                self.randomId = randomId
                self.peer = peer
                self.sponsorInfo = sponsorInfo
                self.additionalInfo = additionalInfo
            }
        }
        case sponsoredPeer(Cons_sponsoredPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredPeer(let _data):
                if boxed {
                    buffer.appendInt32(-963180333)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.randomId, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.sponsorInfo!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.additionalInfo!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sponsoredPeer(let _data):
                return ("sponsoredPeer", [("flags", _data.flags as Any), ("randomId", _data.randomId as Any), ("peer", _data.peer as Any), ("sponsorInfo", _data.sponsorInfo as Any), ("additionalInfo", _data.additionalInfo as Any)])
            }
        }

        public static func parse_sponsoredPeer(_ reader: BufferReader) -> SponsoredPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.SponsoredPeer.sponsoredPeer(Cons_sponsoredPeer(flags: _1!, randomId: _2!, peer: _3!, sponsorInfo: _4, additionalInfo: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGift: TypeConstructorDescription {
        public class Cons_starGift {
            public var flags: Int32
            public var id: Int64
            public var sticker: Api.Document
            public var stars: Int64
            public var availabilityRemains: Int32?
            public var availabilityTotal: Int32?
            public var availabilityResale: Int64?
            public var convertStars: Int64
            public var firstSaleDate: Int32?
            public var lastSaleDate: Int32?
            public var upgradeStars: Int64?
            public var resellMinStars: Int64?
            public var title: String?
            public var releasedBy: Api.Peer?
            public var perUserTotal: Int32?
            public var perUserRemains: Int32?
            public var lockedUntilDate: Int32?
            public var auctionSlug: String?
            public var giftsPerRound: Int32?
            public var auctionStartDate: Int32?
            public var upgradeVariants: Int32?
            public var background: Api.StarGiftBackground?
            public init(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, availabilityResale: Int64?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?, resellMinStars: Int64?, title: String?, releasedBy: Api.Peer?, perUserTotal: Int32?, perUserRemains: Int32?, lockedUntilDate: Int32?, auctionSlug: String?, giftsPerRound: Int32?, auctionStartDate: Int32?, upgradeVariants: Int32?, background: Api.StarGiftBackground?) {
                self.flags = flags
                self.id = id
                self.sticker = sticker
                self.stars = stars
                self.availabilityRemains = availabilityRemains
                self.availabilityTotal = availabilityTotal
                self.availabilityResale = availabilityResale
                self.convertStars = convertStars
                self.firstSaleDate = firstSaleDate
                self.lastSaleDate = lastSaleDate
                self.upgradeStars = upgradeStars
                self.resellMinStars = resellMinStars
                self.title = title
                self.releasedBy = releasedBy
                self.perUserTotal = perUserTotal
                self.perUserRemains = perUserRemains
                self.lockedUntilDate = lockedUntilDate
                self.auctionSlug = auctionSlug
                self.giftsPerRound = giftsPerRound
                self.auctionStartDate = auctionStartDate
                self.upgradeVariants = upgradeVariants
                self.background = background
            }
        }
        public class Cons_starGiftUnique {
            public var flags: Int32
            public var id: Int64
            public var giftId: Int64
            public var title: String
            public var slug: String
            public var num: Int32
            public var ownerId: Api.Peer?
            public var ownerName: String?
            public var ownerAddress: String?
            public var attributes: [Api.StarGiftAttribute]
            public var availabilityIssued: Int32
            public var availabilityTotal: Int32
            public var giftAddress: String?
            public var resellAmount: [Api.StarsAmount]?
            public var releasedBy: Api.Peer?
            public var valueAmount: Int64?
            public var valueCurrency: String?
            public var valueUsdAmount: Int64?
            public var themePeer: Api.Peer?
            public var peerColor: Api.PeerColor?
            public var hostId: Api.Peer?
            public var offerMinStars: Int32?
            public var craftChancePermille: Int32?
            public init(flags: Int32, id: Int64, giftId: Int64, title: String, slug: String, num: Int32, ownerId: Api.Peer?, ownerName: String?, ownerAddress: String?, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32, giftAddress: String?, resellAmount: [Api.StarsAmount]?, releasedBy: Api.Peer?, valueAmount: Int64?, valueCurrency: String?, valueUsdAmount: Int64?, themePeer: Api.Peer?, peerColor: Api.PeerColor?, hostId: Api.Peer?, offerMinStars: Int32?, craftChancePermille: Int32?) {
                self.flags = flags
                self.id = id
                self.giftId = giftId
                self.title = title
                self.slug = slug
                self.num = num
                self.ownerId = ownerId
                self.ownerName = ownerName
                self.ownerAddress = ownerAddress
                self.attributes = attributes
                self.availabilityIssued = availabilityIssued
                self.availabilityTotal = availabilityTotal
                self.giftAddress = giftAddress
                self.resellAmount = resellAmount
                self.releasedBy = releasedBy
                self.valueAmount = valueAmount
                self.valueCurrency = valueCurrency
                self.valueUsdAmount = valueUsdAmount
                self.themePeer = themePeer
                self.peerColor = peerColor
                self.hostId = hostId
                self.offerMinStars = offerMinStars
                self.craftChancePermille = craftChancePermille
            }
        }
        case starGift(Cons_starGift)
        case starGiftUnique(Cons_starGiftUnique)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGift(let _data):
                if boxed {
                    buffer.appendInt32(825922887)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                _data.sticker.serialize(buffer, true)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.availabilityRemains!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.availabilityTotal!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.availabilityResale!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.convertStars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.firstSaleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.lastSaleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.upgradeStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.resellMinStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.releasedBy!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt32(_data.perUserTotal!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt32(_data.perUserRemains!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeInt32(_data.lockedUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeString(_data.auctionSlug!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.giftsPerRound!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.auctionStartDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt32(_data.upgradeVariants!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    _data.background!.serialize(buffer, true)
                }
                break
            case .starGiftUnique(let _data):
                if boxed {
                    buffer.appendInt32(-2047825459)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                serializeInt32(_data.num, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.ownerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.ownerName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.ownerAddress!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.availabilityIssued, buffer: buffer, boxed: false)
                serializeInt32(_data.availabilityTotal, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.giftAddress!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.resellAmount!.count))
                    for item in _data.resellAmount! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.releasedBy!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.valueAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.valueCurrency!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.valueUsdAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.themePeer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    _data.peerColor!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    _data.hostId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt32(_data.offerMinStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeInt32(_data.craftChancePermille!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGift(let _data):
                return ("starGift", [("flags", _data.flags as Any), ("id", _data.id as Any), ("sticker", _data.sticker as Any), ("stars", _data.stars as Any), ("availabilityRemains", _data.availabilityRemains as Any), ("availabilityTotal", _data.availabilityTotal as Any), ("availabilityResale", _data.availabilityResale as Any), ("convertStars", _data.convertStars as Any), ("firstSaleDate", _data.firstSaleDate as Any), ("lastSaleDate", _data.lastSaleDate as Any), ("upgradeStars", _data.upgradeStars as Any), ("resellMinStars", _data.resellMinStars as Any), ("title", _data.title as Any), ("releasedBy", _data.releasedBy as Any), ("perUserTotal", _data.perUserTotal as Any), ("perUserRemains", _data.perUserRemains as Any), ("lockedUntilDate", _data.lockedUntilDate as Any), ("auctionSlug", _data.auctionSlug as Any), ("giftsPerRound", _data.giftsPerRound as Any), ("auctionStartDate", _data.auctionStartDate as Any), ("upgradeVariants", _data.upgradeVariants as Any), ("background", _data.background as Any)])
            case .starGiftUnique(let _data):
                return ("starGiftUnique", [("flags", _data.flags as Any), ("id", _data.id as Any), ("giftId", _data.giftId as Any), ("title", _data.title as Any), ("slug", _data.slug as Any), ("num", _data.num as Any), ("ownerId", _data.ownerId as Any), ("ownerName", _data.ownerName as Any), ("ownerAddress", _data.ownerAddress as Any), ("attributes", _data.attributes as Any), ("availabilityIssued", _data.availabilityIssued as Any), ("availabilityTotal", _data.availabilityTotal as Any), ("giftAddress", _data.giftAddress as Any), ("resellAmount", _data.resellAmount as Any), ("releasedBy", _data.releasedBy as Any), ("valueAmount", _data.valueAmount as Any), ("valueCurrency", _data.valueCurrency as Any), ("valueUsdAmount", _data.valueUsdAmount as Any), ("themePeer", _data.themePeer as Any), ("peerColor", _data.peerColor as Any), ("hostId", _data.hostId as Any), ("offerMinStars", _data.offerMinStars as Any), ("craftChancePermille", _data.craftChancePermille as Any)])
            }
        }

        public static func parse_starGift(_ reader: BufferReader) -> StarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Int64?
            _8 = reader.readInt64()
            var _9: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {
                _11 = reader.readInt64()
            }
            var _12: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _12 = reader.readInt64()
            }
            var _13: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _13 = parseString(reader)
            }
            var _14: Api.Peer?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _14 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _15: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {
                _15 = reader.readInt32()
            }
            var _16: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {
                _16 = reader.readInt32()
            }
            var _17: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {
                _17 = reader.readInt32()
            }
            var _18: String?
            if Int(_1!) & Int(1 << 11) != 0 {
                _18 = parseString(reader)
            }
            var _19: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _19 = reader.readInt32()
            }
            var _20: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _20 = reader.readInt32()
            }
            var _21: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {
                _21 = reader.readInt32()
            }
            var _22: Api.StarGiftBackground?
            if Int(_1!) & Int(1 << 13) != 0 {
                if let signature = reader.readInt32() {
                    _22 = Api.parse(reader, signature: signature) as? Api.StarGiftBackground
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 4) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 5) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 8) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 9) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 11) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 11) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 11) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 12) == 0) || _21 != nil
            let _c22 = (Int(_1!) & Int(1 << 13) == 0) || _22 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.StarGift.starGift(Cons_starGift(flags: _1!, id: _2!, sticker: _3!, stars: _4!, availabilityRemains: _5, availabilityTotal: _6, availabilityResale: _7, convertStars: _8!, firstSaleDate: _9, lastSaleDate: _10, upgradeStars: _11, resellMinStars: _12, title: _13, releasedBy: _14, perUserTotal: _15, perUserRemains: _16, lockedUntilDate: _17, auctionSlug: _18, giftsPerRound: _19, auctionStartDate: _20, upgradeVariants: _21, background: _22))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftUnique(_ reader: BufferReader) -> StarGift? {
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
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _8: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _8 = parseString(reader)
            }
            var _9: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _9 = parseString(reader)
            }
            var _10: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _13 = parseString(reader)
            }
            var _14: [Api.StarsAmount]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsAmount.self)
                }
            }
            var _15: Api.Peer?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _16: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _16 = reader.readInt64()
            }
            var _17: String?
            if Int(_1!) & Int(1 << 8) != 0 {
                _17 = parseString(reader)
            }
            var _18: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _18 = reader.readInt64()
            }
            var _19: Api.Peer?
            if Int(_1!) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _19 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _20: Api.PeerColor?
            if Int(_1!) & Int(1 << 11) != 0 {
                if let signature = reader.readInt32() {
                    _20 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _21: Api.Peer?
            if Int(_1!) & Int(1 << 12) != 0 {
                if let signature = reader.readInt32() {
                    _21 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _22: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {
                _22 = reader.readInt32()
            }
            var _23: Int32?
            if Int(_1!) & Int(1 << 16) != 0 {
                _23 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 3) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 4) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 5) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 8) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 8) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 10) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 11) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 12) == 0) || _21 != nil
            let _c22 = (Int(_1!) & Int(1 << 13) == 0) || _22 != nil
            let _c23 = (Int(_1!) & Int(1 << 16) == 0) || _23 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 {
                return Api.StarGift.starGiftUnique(Cons_starGiftUnique(flags: _1!, id: _2!, giftId: _3!, title: _4!, slug: _5!, num: _6!, ownerId: _7, ownerName: _8, ownerAddress: _9, attributes: _10!, availabilityIssued: _11!, availabilityTotal: _12!, giftAddress: _13, resellAmount: _14, releasedBy: _15, valueAmount: _16, valueCurrency: _17, valueUsdAmount: _18, themePeer: _19, peerColor: _20, hostId: _21, offerMinStars: _22, craftChancePermille: _23))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftActiveAuctionState: TypeConstructorDescription {
        public class Cons_starGiftActiveAuctionState {
            public var gift: Api.StarGift
            public var state: Api.StarGiftAuctionState
            public var userState: Api.StarGiftAuctionUserState
            public init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState) {
                self.gift = gift
                self.state = state
                self.userState = userState
            }
        }
        case starGiftActiveAuctionState(Cons_starGiftActiveAuctionState)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftActiveAuctionState(let _data):
                if boxed {
                    buffer.appendInt32(-753154979)
                }
                _data.gift.serialize(buffer, true)
                _data.state.serialize(buffer, true)
                _data.userState.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftActiveAuctionState(let _data):
                return ("starGiftActiveAuctionState", [("gift", _data.gift as Any), ("state", _data.state as Any), ("userState", _data.userState as Any)])
            }
        }

        public static func parse_starGiftActiveAuctionState(_ reader: BufferReader) -> StarGiftActiveAuctionState? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _2: Api.StarGiftAuctionState?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionState
            }
            var _3: Api.StarGiftAuctionUserState?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionUserState
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarGiftActiveAuctionState.starGiftActiveAuctionState(Cons_starGiftActiveAuctionState(gift: _1!, state: _2!, userState: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttribute: TypeConstructorDescription {
        public class Cons_starGiftAttributeBackdrop {
            public var name: String
            public var backdropId: Int32
            public var centerColor: Int32
            public var edgeColor: Int32
            public var patternColor: Int32
            public var textColor: Int32
            public var rarity: Api.StarGiftAttributeRarity
            public init(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarity: Api.StarGiftAttributeRarity) {
                self.name = name
                self.backdropId = backdropId
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.patternColor = patternColor
                self.textColor = textColor
                self.rarity = rarity
            }
        }
        public class Cons_starGiftAttributeModel {
            public var flags: Int32
            public var name: String
            public var document: Api.Document
            public var rarity: Api.StarGiftAttributeRarity
            public init(flags: Int32, name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
                self.flags = flags
                self.name = name
                self.document = document
                self.rarity = rarity
            }
        }
        public class Cons_starGiftAttributeOriginalDetails {
            public var flags: Int32
            public var senderId: Api.Peer?
            public var recipientId: Api.Peer
            public var date: Int32
            public var message: Api.TextWithEntities?
            public init(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?) {
                self.flags = flags
                self.senderId = senderId
                self.recipientId = recipientId
                self.date = date
                self.message = message
            }
        }
        public class Cons_starGiftAttributePattern {
            public var name: String
            public var document: Api.Document
            public var rarity: Api.StarGiftAttributeRarity
            public init(name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
                self.name = name
                self.document = document
                self.rarity = rarity
            }
        }
        case starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop)
        case starGiftAttributeModel(Cons_starGiftAttributeModel)
        case starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails)
        case starGiftAttributePattern(Cons_starGiftAttributePattern)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeBackdrop(let _data):
                if boxed {
                    buffer.appendInt32(-1624963868)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeInt32(_data.backdropId, buffer: buffer, boxed: false)
                serializeInt32(_data.centerColor, buffer: buffer, boxed: false)
                serializeInt32(_data.edgeColor, buffer: buffer, boxed: false)
                serializeInt32(_data.patternColor, buffer: buffer, boxed: false)
                serializeInt32(_data.textColor, buffer: buffer, boxed: false)
                _data.rarity.serialize(buffer, true)
                break
            case .starGiftAttributeModel(let _data):
                if boxed {
                    buffer.appendInt32(1448235490)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                _data.rarity.serialize(buffer, true)
                break
            case .starGiftAttributeOriginalDetails(let _data):
                if boxed {
                    buffer.appendInt32(-524291476)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.senderId!.serialize(buffer, true)
                }
                _data.recipientId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .starGiftAttributePattern(let _data):
                if boxed {
                    buffer.appendInt32(1315997162)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                _data.rarity.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeBackdrop(let _data):
                return ("starGiftAttributeBackdrop", [("name", _data.name as Any), ("backdropId", _data.backdropId as Any), ("centerColor", _data.centerColor as Any), ("edgeColor", _data.edgeColor as Any), ("patternColor", _data.patternColor as Any), ("textColor", _data.textColor as Any), ("rarity", _data.rarity as Any)])
            case .starGiftAttributeModel(let _data):
                return ("starGiftAttributeModel", [("flags", _data.flags as Any), ("name", _data.name as Any), ("document", _data.document as Any), ("rarity", _data.rarity as Any)])
            case .starGiftAttributeOriginalDetails(let _data):
                return ("starGiftAttributeOriginalDetails", [("flags", _data.flags as Any), ("senderId", _data.senderId as Any), ("recipientId", _data.recipientId as Any), ("date", _data.date as Any), ("message", _data.message as Any)])
            case .starGiftAttributePattern(let _data):
                return ("starGiftAttributePattern", [("name", _data.name as Any), ("document", _data.document as Any), ("rarity", _data.rarity as Any)])
            }
        }

        public static func parse_starGiftAttributeBackdrop(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
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
            var _7: Api.StarGiftAttributeRarity?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeRarity
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarGiftAttribute.starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop(name: _1!, backdropId: _2!, centerColor: _3!, edgeColor: _4!, patternColor: _5!, textColor: _6!, rarity: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeModel(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _4: Api.StarGiftAttributeRarity?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeRarity
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StarGiftAttribute.starGiftAttributeModel(Cons_starGiftAttributeModel(flags: _1!, name: _2!, document: _3!, rarity: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeOriginalDetails(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarGiftAttribute.starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails(flags: _1!, senderId: _2, recipientId: _3!, date: _4!, message: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributePattern(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _3: Api.StarGiftAttributeRarity?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeRarity
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarGiftAttribute.starGiftAttributePattern(Cons_starGiftAttributePattern(name: _1!, document: _2!, rarity: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttributeCounter: TypeConstructorDescription {
        public class Cons_starGiftAttributeCounter {
            public var attribute: Api.StarGiftAttributeId
            public var count: Int32
            public init(attribute: Api.StarGiftAttributeId, count: Int32) {
                self.attribute = attribute
                self.count = count
            }
        }
        case starGiftAttributeCounter(Cons_starGiftAttributeCounter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeCounter(let _data):
                if boxed {
                    buffer.appendInt32(783398488)
                }
                _data.attribute.serialize(buffer, true)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeCounter(let _data):
                return ("starGiftAttributeCounter", [("attribute", _data.attribute as Any), ("count", _data.count as Any)])
            }
        }

        public static func parse_starGiftAttributeCounter(_ reader: BufferReader) -> StarGiftAttributeCounter? {
            var _1: Api.StarGiftAttributeId?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeId
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarGiftAttributeCounter.starGiftAttributeCounter(Cons_starGiftAttributeCounter(attribute: _1!, count: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttributeId: TypeConstructorDescription {
        public class Cons_starGiftAttributeIdBackdrop {
            public var backdropId: Int32
            public init(backdropId: Int32) {
                self.backdropId = backdropId
            }
        }
        public class Cons_starGiftAttributeIdModel {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
        }
        public class Cons_starGiftAttributeIdPattern {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
        }
        case starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop)
        case starGiftAttributeIdModel(Cons_starGiftAttributeIdModel)
        case starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeIdBackdrop(let _data):
                if boxed {
                    buffer.appendInt32(520210263)
                }
                serializeInt32(_data.backdropId, buffer: buffer, boxed: false)
                break
            case .starGiftAttributeIdModel(let _data):
                if boxed {
                    buffer.appendInt32(1219145276)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                break
            case .starGiftAttributeIdPattern(let _data):
                if boxed {
                    buffer.appendInt32(1242965043)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeIdBackdrop(let _data):
                return ("starGiftAttributeIdBackdrop", [("backdropId", _data.backdropId as Any)])
            case .starGiftAttributeIdModel(let _data):
                return ("starGiftAttributeIdModel", [("documentId", _data.documentId as Any)])
            case .starGiftAttributeIdPattern(let _data):
                return ("starGiftAttributeIdPattern", [("documentId", _data.documentId as Any)])
            }
        }

        public static func parse_starGiftAttributeIdBackdrop(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeId.starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop(backdropId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeIdModel(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeId.starGiftAttributeIdModel(Cons_starGiftAttributeIdModel(documentId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeIdPattern(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeId.starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern(documentId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttributeRarity: TypeConstructorDescription {
        public class Cons_starGiftAttributeRarity {
            public var permille: Int32
            public init(permille: Int32) {
                self.permille = permille
            }
        }
        case starGiftAttributeRarity(Cons_starGiftAttributeRarity)
        case starGiftAttributeRarityEpic
        case starGiftAttributeRarityLegendary
        case starGiftAttributeRarityRare
        case starGiftAttributeRarityUncommon

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeRarity(let _data):
                if boxed {
                    buffer.appendInt32(910391095)
                }
                serializeInt32(_data.permille, buffer: buffer, boxed: false)
                break
            case .starGiftAttributeRarityEpic:
                if boxed {
                    buffer.appendInt32(2029777832)
                }
                break
            case .starGiftAttributeRarityLegendary:
                if boxed {
                    buffer.appendInt32(-822614104)
                }
                break
            case .starGiftAttributeRarityRare:
                if boxed {
                    buffer.appendInt32(-259174037)
                }
                break
            case .starGiftAttributeRarityUncommon:
                if boxed {
                    buffer.appendInt32(-607231095)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeRarity(let _data):
                return ("starGiftAttributeRarity", [("permille", _data.permille as Any)])
            case .starGiftAttributeRarityEpic:
                return ("starGiftAttributeRarityEpic", [])
            case .starGiftAttributeRarityLegendary:
                return ("starGiftAttributeRarityLegendary", [])
            case .starGiftAttributeRarityRare:
                return ("starGiftAttributeRarityRare", [])
            case .starGiftAttributeRarityUncommon:
                return ("starGiftAttributeRarityUncommon", [])
            }
        }

        public static func parse_starGiftAttributeRarity(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeRarity.starGiftAttributeRarity(Cons_starGiftAttributeRarity(permille: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeRarityEpic(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityEpic
        }
        public static func parse_starGiftAttributeRarityLegendary(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityLegendary
        }
        public static func parse_starGiftAttributeRarityRare(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityRare
        }
        public static func parse_starGiftAttributeRarityUncommon(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityUncommon
        }
    }
}
public extension Api {
    enum StarGiftAuctionAcquiredGift: TypeConstructorDescription {
        public class Cons_starGiftAuctionAcquiredGift {
            public var flags: Int32
            public var peer: Api.Peer
            public var date: Int32
            public var bidAmount: Int64
            public var round: Int32
            public var pos: Int32
            public var message: Api.TextWithEntities?
            public var giftNum: Int32?
            public init(flags: Int32, peer: Api.Peer, date: Int32, bidAmount: Int64, round: Int32, pos: Int32, message: Api.TextWithEntities?, giftNum: Int32?) {
                self.flags = flags
                self.peer = peer
                self.date = date
                self.bidAmount = bidAmount
                self.round = round
                self.pos = pos
                self.message = message
                self.giftNum = giftNum
            }
        }
        case starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionAcquiredGift(let _data):
                if boxed {
                    buffer.appendInt32(1118831432)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.bidAmount, buffer: buffer, boxed: false)
                serializeInt32(_data.round, buffer: buffer, boxed: false)
                serializeInt32(_data.pos, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.giftNum!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionAcquiredGift(let _data):
                return ("starGiftAuctionAcquiredGift", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("date", _data.date as Any), ("bidAmount", _data.bidAmount as Any), ("round", _data.round as Any), ("pos", _data.pos as Any), ("message", _data.message as Any), ("giftNum", _data.giftNum as Any)])
            }
        }

        public static func parse_starGiftAuctionAcquiredGift(_ reader: BufferReader) -> StarGiftAuctionAcquiredGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _8 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.StarGiftAuctionAcquiredGift.starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift(flags: _1!, peer: _2!, date: _3!, bidAmount: _4!, round: _5!, pos: _6!, message: _7, giftNum: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAuctionRound: TypeConstructorDescription {
        public class Cons_starGiftAuctionRound {
            public var num: Int32
            public var duration: Int32
            public init(num: Int32, duration: Int32) {
                self.num = num
                self.duration = duration
            }
        }
        public class Cons_starGiftAuctionRoundExtendable {
            public var num: Int32
            public var duration: Int32
            public var extendTop: Int32
            public var extendWindow: Int32
            public init(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32) {
                self.num = num
                self.duration = duration
                self.extendTop = extendTop
                self.extendWindow = extendWindow
            }
        }
        case starGiftAuctionRound(Cons_starGiftAuctionRound)
        case starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionRound(let _data):
                if boxed {
                    buffer.appendInt32(984483112)
                }
                serializeInt32(_data.num, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                break
            case .starGiftAuctionRoundExtendable(let _data):
                if boxed {
                    buffer.appendInt32(178266597)
                }
                serializeInt32(_data.num, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                serializeInt32(_data.extendTop, buffer: buffer, boxed: false)
                serializeInt32(_data.extendWindow, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionRound(let _data):
                return ("starGiftAuctionRound", [("num", _data.num as Any), ("duration", _data.duration as Any)])
            case .starGiftAuctionRoundExtendable(let _data):
                return ("starGiftAuctionRoundExtendable", [("num", _data.num as Any), ("duration", _data.duration as Any), ("extendTop", _data.extendTop as Any), ("extendWindow", _data.extendWindow as Any)])
            }
        }

        public static func parse_starGiftAuctionRound(_ reader: BufferReader) -> StarGiftAuctionRound? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarGiftAuctionRound.starGiftAuctionRound(Cons_starGiftAuctionRound(num: _1!, duration: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAuctionRoundExtendable(_ reader: BufferReader) -> StarGiftAuctionRound? {
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
                return Api.StarGiftAuctionRound.starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable(num: _1!, duration: _2!, extendTop: _3!, extendWindow: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAuctionState: TypeConstructorDescription {
        public class Cons_starGiftAuctionState {
            public var version: Int32
            public var startDate: Int32
            public var endDate: Int32
            public var minBidAmount: Int64
            public var bidLevels: [Api.AuctionBidLevel]
            public var topBidders: [Int64]
            public var nextRoundAt: Int32
            public var lastGiftNum: Int32
            public var giftsLeft: Int32
            public var currentRound: Int32
            public var totalRounds: Int32
            public var rounds: [Api.StarGiftAuctionRound]
            public init(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [Api.AuctionBidLevel], topBidders: [Int64], nextRoundAt: Int32, lastGiftNum: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Api.StarGiftAuctionRound]) {
                self.version = version
                self.startDate = startDate
                self.endDate = endDate
                self.minBidAmount = minBidAmount
                self.bidLevels = bidLevels
                self.topBidders = topBidders
                self.nextRoundAt = nextRoundAt
                self.lastGiftNum = lastGiftNum
                self.giftsLeft = giftsLeft
                self.currentRound = currentRound
                self.totalRounds = totalRounds
                self.rounds = rounds
            }
        }
        public class Cons_starGiftAuctionStateFinished {
            public var flags: Int32
            public var startDate: Int32
            public var endDate: Int32
            public var averagePrice: Int64
            public var listedCount: Int32?
            public var fragmentListedCount: Int32?
            public var fragmentListedUrl: String?
            public init(flags: Int32, startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
                self.flags = flags
                self.startDate = startDate
                self.endDate = endDate
                self.averagePrice = averagePrice
                self.listedCount = listedCount
                self.fragmentListedCount = fragmentListedCount
                self.fragmentListedUrl = fragmentListedUrl
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)
        case starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished)
        case starGiftAuctionStateNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionState(let _data):
                if boxed {
                    buffer.appendInt32(1998212710)
                }
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                serializeInt32(_data.startDate, buffer: buffer, boxed: false)
                serializeInt32(_data.endDate, buffer: buffer, boxed: false)
                serializeInt64(_data.minBidAmount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.bidLevels.count))
                for item in _data.bidLevels {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topBidders.count))
                for item in _data.topBidders {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.nextRoundAt, buffer: buffer, boxed: false)
                serializeInt32(_data.lastGiftNum, buffer: buffer, boxed: false)
                serializeInt32(_data.giftsLeft, buffer: buffer, boxed: false)
                serializeInt32(_data.currentRound, buffer: buffer, boxed: false)
                serializeInt32(_data.totalRounds, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rounds.count))
                for item in _data.rounds {
                    item.serialize(buffer, true)
                }
                break
            case .starGiftAuctionStateFinished(let _data):
                if boxed {
                    buffer.appendInt32(-1758614593)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.startDate, buffer: buffer, boxed: false)
                serializeInt32(_data.endDate, buffer: buffer, boxed: false)
                serializeInt64(_data.averagePrice, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.listedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.fragmentListedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.fragmentListedUrl!, buffer: buffer, boxed: false)
                }
                break
            case .starGiftAuctionStateNotModified:
                if boxed {
                    buffer.appendInt32(-30197422)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionState(let _data):
                return ("starGiftAuctionState", [("version", _data.version as Any), ("startDate", _data.startDate as Any), ("endDate", _data.endDate as Any), ("minBidAmount", _data.minBidAmount as Any), ("bidLevels", _data.bidLevels as Any), ("topBidders", _data.topBidders as Any), ("nextRoundAt", _data.nextRoundAt as Any), ("lastGiftNum", _data.lastGiftNum as Any), ("giftsLeft", _data.giftsLeft as Any), ("currentRound", _data.currentRound as Any), ("totalRounds", _data.totalRounds as Any), ("rounds", _data.rounds as Any)])
            case .starGiftAuctionStateFinished(let _data):
                return ("starGiftAuctionStateFinished", [("flags", _data.flags as Any), ("startDate", _data.startDate as Any), ("endDate", _data.endDate as Any), ("averagePrice", _data.averagePrice as Any), ("listedCount", _data.listedCount as Any), ("fragmentListedCount", _data.fragmentListedCount as Any), ("fragmentListedUrl", _data.fragmentListedUrl as Any)])
            case .starGiftAuctionStateNotModified:
                return ("starGiftAuctionStateNotModified", [])
            }
        }

        public static func parse_starGiftAuctionState(_ reader: BufferReader) -> StarGiftAuctionState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: [Api.AuctionBidLevel]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AuctionBidLevel.self)
            }
            var _6: [Int64]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: [Api.StarGiftAuctionRound]?
            if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAuctionRound.self)
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
            let _c12 = _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.StarGiftAuctionState.starGiftAuctionState(Cons_starGiftAuctionState(version: _1!, startDate: _2!, endDate: _3!, minBidAmount: _4!, bidLevels: _5!, topBidders: _6!, nextRoundAt: _7!, lastGiftNum: _8!, giftsLeft: _9!, currentRound: _10!, totalRounds: _11!, rounds: _12!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAuctionStateFinished(_ reader: BufferReader) -> StarGiftAuctionState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
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
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarGiftAuctionState.starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished(flags: _1!, startDate: _2!, endDate: _3!, averagePrice: _4!, listedCount: _5, fragmentListedCount: _6, fragmentListedUrl: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAuctionStateNotModified(_ reader: BufferReader) -> StarGiftAuctionState? {
            return Api.StarGiftAuctionState.starGiftAuctionStateNotModified
        }
    }
}
public extension Api {
    enum StarGiftAuctionUserState: TypeConstructorDescription {
        public class Cons_starGiftAuctionUserState {
            public var flags: Int32
            public var bidAmount: Int64?
            public var bidDate: Int32?
            public var minBidAmount: Int64?
            public var bidPeer: Api.Peer?
            public var acquiredCount: Int32
            public init(flags: Int32, bidAmount: Int64?, bidDate: Int32?, minBidAmount: Int64?, bidPeer: Api.Peer?, acquiredCount: Int32) {
                self.flags = flags
                self.bidAmount = bidAmount
                self.bidDate = bidDate
                self.minBidAmount = minBidAmount
                self.bidPeer = bidPeer
                self.acquiredCount = acquiredCount
            }
        }
        case starGiftAuctionUserState(Cons_starGiftAuctionUserState)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionUserState(let _data):
                if boxed {
                    buffer.appendInt32(787403204)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.bidAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.bidDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.minBidAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.bidPeer!.serialize(buffer, true)
                }
                serializeInt32(_data.acquiredCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionUserState(let _data):
                return ("starGiftAuctionUserState", [("flags", _data.flags as Any), ("bidAmount", _data.bidAmount as Any), ("bidDate", _data.bidDate as Any), ("minBidAmount", _data.minBidAmount as Any), ("bidPeer", _data.bidPeer as Any), ("acquiredCount", _data.acquiredCount as Any)])
            }
        }

        public static func parse_starGiftAuctionUserState(_ reader: BufferReader) -> StarGiftAuctionUserState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarGiftAuctionUserState.starGiftAuctionUserState(Cons_starGiftAuctionUserState(flags: _1!, bidAmount: _2, bidDate: _3, minBidAmount: _4, bidPeer: _5, acquiredCount: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftBackground: TypeConstructorDescription {
        public class Cons_starGiftBackground {
            public var centerColor: Int32
            public var edgeColor: Int32
            public var textColor: Int32
            public init(centerColor: Int32, edgeColor: Int32, textColor: Int32) {
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.textColor = textColor
            }
        }
        case starGiftBackground(Cons_starGiftBackground)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftBackground(let _data):
                if boxed {
                    buffer.appendInt32(-1342872680)
                }
                serializeInt32(_data.centerColor, buffer: buffer, boxed: false)
                serializeInt32(_data.edgeColor, buffer: buffer, boxed: false)
                serializeInt32(_data.textColor, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftBackground(let _data):
                return ("starGiftBackground", [("centerColor", _data.centerColor as Any), ("edgeColor", _data.edgeColor as Any), ("textColor", _data.textColor as Any)])
            }
        }

        public static func parse_starGiftBackground(_ reader: BufferReader) -> StarGiftBackground? {
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
                return Api.StarGiftBackground.starGiftBackground(Cons_starGiftBackground(centerColor: _1!, edgeColor: _2!, textColor: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftCollection: TypeConstructorDescription {
        public class Cons_starGiftCollection {
            public var flags: Int32
            public var collectionId: Int32
            public var title: String
            public var icon: Api.Document?
            public var giftsCount: Int32
            public var hash: Int64
            public init(flags: Int32, collectionId: Int32, title: String, icon: Api.Document?, giftsCount: Int32, hash: Int64) {
                self.flags = flags
                self.collectionId = collectionId
                self.title = title
                self.icon = icon
                self.giftsCount = giftsCount
                self.hash = hash
            }
        }
        case starGiftCollection(Cons_starGiftCollection)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftCollection(let _data):
                if boxed {
                    buffer.appendInt32(-1653926992)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.collectionId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.icon!.serialize(buffer, true)
                }
                serializeInt32(_data.giftsCount, buffer: buffer, boxed: false)
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftCollection(let _data):
                return ("starGiftCollection", [("flags", _data.flags as Any), ("collectionId", _data.collectionId as Any), ("title", _data.title as Any), ("icon", _data.icon as Any), ("giftsCount", _data.giftsCount as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_starGiftCollection(_ reader: BufferReader) -> StarGiftCollection? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarGiftCollection.starGiftCollection(Cons_starGiftCollection(flags: _1!, collectionId: _2!, title: _3!, icon: _4, giftsCount: _5!, hash: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftUpgradePrice: TypeConstructorDescription {
        public class Cons_starGiftUpgradePrice {
            public var date: Int32
            public var upgradeStars: Int64
            public init(date: Int32, upgradeStars: Int64) {
                self.date = date
                self.upgradeStars = upgradeStars
            }
        }
        case starGiftUpgradePrice(Cons_starGiftUpgradePrice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftUpgradePrice(let _data):
                if boxed {
                    buffer.appendInt32(-1712704739)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.upgradeStars, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftUpgradePrice(let _data):
                return ("starGiftUpgradePrice", [("date", _data.date as Any), ("upgradeStars", _data.upgradeStars as Any)])
            }
        }

        public static func parse_starGiftUpgradePrice(_ reader: BufferReader) -> StarGiftUpgradePrice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarGiftUpgradePrice.starGiftUpgradePrice(Cons_starGiftUpgradePrice(date: _1!, upgradeStars: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarRefProgram: TypeConstructorDescription {
        public class Cons_starRefProgram {
            public var flags: Int32
            public var botId: Int64
            public var commissionPermille: Int32
            public var durationMonths: Int32?
            public var endDate: Int32?
            public var dailyRevenuePerUser: Api.StarsAmount?
            public init(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?) {
                self.flags = flags
                self.botId = botId
                self.commissionPermille = commissionPermille
                self.durationMonths = durationMonths
                self.endDate = endDate
                self.dailyRevenuePerUser = dailyRevenuePerUser
            }
        }
        case starRefProgram(Cons_starRefProgram)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starRefProgram(let _data):
                if boxed {
                    buffer.appendInt32(-586389774)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeInt32(_data.commissionPermille, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.durationMonths!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.endDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.dailyRevenuePerUser!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starRefProgram(let _data):
                return ("starRefProgram", [("flags", _data.flags as Any), ("botId", _data.botId as Any), ("commissionPermille", _data.commissionPermille as Any), ("durationMonths", _data.durationMonths as Any), ("endDate", _data.endDate as Any), ("dailyRevenuePerUser", _data.dailyRevenuePerUser as Any)])
            }
        }

        public static func parse_starRefProgram(_ reader: BufferReader) -> StarRefProgram? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Api.StarsAmount?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.StarsAmount
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarRefProgram.starRefProgram(Cons_starRefProgram(flags: _1!, botId: _2!, commissionPermille: _3!, durationMonths: _4, endDate: _5, dailyRevenuePerUser: _6))
            }
            else {
                return nil
            }
        }
    }
}
