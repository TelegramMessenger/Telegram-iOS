public extension Api {
    enum ShippingOption: TypeConstructorDescription {
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
                return ("shippingOption", [("id", id as Any), ("title", title as Any), ("prices", prices as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.ShippingOption.shippingOption(id: _1!, title: _2!, prices: _3!)
        }
    
    }
}
public extension Api {
    enum SmsJob: TypeConstructorDescription {
        case smsJob(jobId: String, phoneNumber: String, text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .smsJob(let jobId, let phoneNumber, let text):
                    if boxed {
                        buffer.appendInt32(-425595208)
                    }
                    serializeString(jobId, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .smsJob(let jobId, let phoneNumber, let text):
                return ("smsJob", [("jobId", jobId as Any), ("phoneNumber", phoneNumber as Any), ("text", text as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.SmsJob.smsJob(jobId: _1!, phoneNumber: _2!, text: _3!)
        }
    
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        case sponsoredMessage(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?, minDisplayDuration: Int32?, maxDisplayDuration: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessage(let flags, let randomId, let url, let title, let message, let entities, let photo, let media, let color, let buttonText, let sponsorInfo, let additionalInfo, let minDisplayDuration, let maxDisplayDuration):
                    if boxed {
                        buffer.appendInt32(2109703795)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 13) != 0 {color!.serialize(buffer, true)}
                    serializeString(buttonText, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {serializeString(sponsorInfo!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(additionalInfo!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(minDisplayDuration!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(maxDisplayDuration!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessage(let flags, let randomId, let url, let title, let message, let entities, let photo, let media, let color, let buttonText, let sponsorInfo, let additionalInfo, let minDisplayDuration, let maxDisplayDuration):
                return ("sponsoredMessage", [("flags", flags as Any), ("randomId", randomId as Any), ("url", url as Any), ("title", title as Any), ("message", message as Any), ("entities", entities as Any), ("photo", photo as Any), ("media", media as Any), ("color", color as Any), ("buttonText", buttonText as Any), ("sponsorInfo", sponsorInfo as Any), ("additionalInfo", additionalInfo as Any), ("minDisplayDuration", minDisplayDuration as Any), ("maxDisplayDuration", maxDisplayDuration as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _7: Api.Photo?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _8: Api.MessageMedia?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _9: Api.PeerColor?
            if Int(_1!) & Int(1 << 13) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PeerColor
            } }
            var _10: String?
            _10 = parseString(reader)
            var _11: String?
            if Int(_1!) & Int(1 << 7) != 0 {_11 = parseString(reader) }
            var _12: String?
            if Int(_1!) & Int(1 << 8) != 0 {_12 = parseString(reader) }
            var _13: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {_14 = reader.readInt32() }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            if !_c12 { return nil }
            if !_c13 { return nil }
            if !_c14 { return nil }
            return Api.SponsoredMessage.sponsoredMessage(flags: _1!, randomId: _2!, url: _3!, title: _4!, message: _5!, entities: _6, photo: _7, media: _8, color: _9, buttonText: _10!, sponsorInfo: _11, additionalInfo: _12, minDisplayDuration: _13, maxDisplayDuration: _14)
        }
    
    }
}
public extension Api {
    enum SponsoredMessageReportOption: TypeConstructorDescription {
        case sponsoredMessageReportOption(text: String, option: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessageReportOption(let text, let option):
                    if boxed {
                        buffer.appendInt32(1124938064)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessageReportOption(let text, let option):
                return ("sponsoredMessageReportOption", [("text", text as Any), ("option", option as Any)])
    }
    }
    
        public static func parse_sponsoredMessageReportOption(_ reader: BufferReader) -> SponsoredMessageReportOption? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.SponsoredMessageReportOption.sponsoredMessageReportOption(text: _1!, option: _2!)
        }
    
    }
}
public extension Api {
    enum SponsoredPeer: TypeConstructorDescription {
        case sponsoredPeer(flags: Int32, randomId: Buffer, peer: Api.Peer, sponsorInfo: String?, additionalInfo: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredPeer(let flags, let randomId, let peer, let sponsorInfo, let additionalInfo):
                    if boxed {
                        buffer.appendInt32(-963180333)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(sponsorInfo!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(additionalInfo!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredPeer(let flags, let randomId, let peer, let sponsorInfo, let additionalInfo):
                return ("sponsoredPeer", [("flags", flags as Any), ("randomId", randomId as Any), ("peer", peer as Any), ("sponsorInfo", sponsorInfo as Any), ("additionalInfo", additionalInfo as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.SponsoredPeer.sponsoredPeer(flags: _1!, randomId: _2!, peer: _3!, sponsorInfo: _4, additionalInfo: _5)
        }
    
    }
}
public extension Api {
    enum StarGift: TypeConstructorDescription {
        case starGift(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, availabilityResale: Int64?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?, resellMinStars: Int64?, title: String?, releasedBy: Api.Peer?, perUserTotal: Int32?, perUserRemains: Int32?, lockedUntilDate: Int32?, auctionSlug: String?, giftsPerRound: Int32?, auctionStartDate: Int32?, upgradeVariants: Int32?, background: Api.StarGiftBackground?)
        case starGiftUnique(flags: Int32, id: Int64, giftId: Int64, title: String, slug: String, num: Int32, ownerId: Api.Peer?, ownerName: String?, ownerAddress: String?, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32, giftAddress: String?, resellAmount: [Api.StarsAmount]?, releasedBy: Api.Peer?, valueAmount: Int64?, valueCurrency: String?, valueUsdAmount: Int64?, themePeer: Api.Peer?, peerColor: Api.PeerColor?, hostId: Api.Peer?, offerMinStars: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGift(let flags, let id, let sticker, let stars, let availabilityRemains, let availabilityTotal, let availabilityResale, let convertStars, let firstSaleDate, let lastSaleDate, let upgradeStars, let resellMinStars, let title, let releasedBy, let perUserTotal, let perUserRemains, let lockedUntilDate, let auctionSlug, let giftsPerRound, let auctionStartDate, let upgradeVariants, let background):
                    if boxed {
                        buffer.appendInt32(825922887)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    sticker.serialize(buffer, true)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(availabilityRemains!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(availabilityTotal!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(availabilityResale!, buffer: buffer, boxed: false)}
                    serializeInt64(convertStars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(firstSaleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(lastSaleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(upgradeStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(resellMinStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {releasedBy!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt32(perUserTotal!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt32(perUserRemains!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(lockedUntilDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(auctionSlug!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(giftsPerRound!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(auctionStartDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 12) != 0 {serializeInt32(upgradeVariants!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {background!.serialize(buffer, true)}
                    break
                case .starGiftUnique(let flags, let id, let giftId, let title, let slug, let num, let ownerId, let ownerName, let ownerAddress, let attributes, let availabilityIssued, let availabilityTotal, let giftAddress, let resellAmount, let releasedBy, let valueAmount, let valueCurrency, let valueUsdAmount, let themePeer, let peerColor, let hostId, let offerMinStars):
                    if boxed {
                        buffer.appendInt32(1453155529)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(giftId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeInt32(num, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {ownerId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(ownerName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(ownerAddress!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(availabilityIssued, buffer: buffer, boxed: false)
                    serializeInt32(availabilityTotal, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(giftAddress!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(resellAmount!.count))
                    for item in resellAmount! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {releasedBy!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt64(valueAmount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(valueCurrency!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt64(valueUsdAmount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {themePeer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {peerColor!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 12) != 0 {hostId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt32(offerMinStars!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGift(let flags, let id, let sticker, let stars, let availabilityRemains, let availabilityTotal, let availabilityResale, let convertStars, let firstSaleDate, let lastSaleDate, let upgradeStars, let resellMinStars, let title, let releasedBy, let perUserTotal, let perUserRemains, let lockedUntilDate, let auctionSlug, let giftsPerRound, let auctionStartDate, let upgradeVariants, let background):
                return ("starGift", [("flags", flags as Any), ("id", id as Any), ("sticker", sticker as Any), ("stars", stars as Any), ("availabilityRemains", availabilityRemains as Any), ("availabilityTotal", availabilityTotal as Any), ("availabilityResale", availabilityResale as Any), ("convertStars", convertStars as Any), ("firstSaleDate", firstSaleDate as Any), ("lastSaleDate", lastSaleDate as Any), ("upgradeStars", upgradeStars as Any), ("resellMinStars", resellMinStars as Any), ("title", title as Any), ("releasedBy", releasedBy as Any), ("perUserTotal", perUserTotal as Any), ("perUserRemains", perUserRemains as Any), ("lockedUntilDate", lockedUntilDate as Any), ("auctionSlug", auctionSlug as Any), ("giftsPerRound", giftsPerRound as Any), ("auctionStartDate", auctionStartDate as Any), ("upgradeVariants", upgradeVariants as Any), ("background", background as Any)])
                case .starGiftUnique(let flags, let id, let giftId, let title, let slug, let num, let ownerId, let ownerName, let ownerAddress, let attributes, let availabilityIssued, let availabilityTotal, let giftAddress, let resellAmount, let releasedBy, let valueAmount, let valueCurrency, let valueUsdAmount, let themePeer, let peerColor, let hostId, let offerMinStars):
                return ("starGiftUnique", [("flags", flags as Any), ("id", id as Any), ("giftId", giftId as Any), ("title", title as Any), ("slug", slug as Any), ("num", num as Any), ("ownerId", ownerId as Any), ("ownerName", ownerName as Any), ("ownerAddress", ownerAddress as Any), ("attributes", attributes as Any), ("availabilityIssued", availabilityIssued as Any), ("availabilityTotal", availabilityTotal as Any), ("giftAddress", giftAddress as Any), ("resellAmount", resellAmount as Any), ("releasedBy", releasedBy as Any), ("valueAmount", valueAmount as Any), ("valueCurrency", valueCurrency as Any), ("valueUsdAmount", valueUsdAmount as Any), ("themePeer", themePeer as Any), ("peerColor", peerColor as Any), ("hostId", hostId as Any), ("offerMinStars", offerMinStars as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            var _7: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = reader.readInt64() }
            var _8: Int64?
            _8 = reader.readInt64()
            var _9: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_10 = reader.readInt32() }
            var _11: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_11 = reader.readInt64() }
            var _12: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_12 = reader.readInt64() }
            var _13: String?
            if Int(_1!) & Int(1 << 5) != 0 {_13 = parseString(reader) }
            var _14: Api.Peer?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _15: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {_15 = reader.readInt32() }
            var _16: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {_16 = reader.readInt32() }
            var _17: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {_17 = reader.readInt32() }
            var _18: String?
            if Int(_1!) & Int(1 << 11) != 0 {_18 = parseString(reader) }
            var _19: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_19 = reader.readInt32() }
            var _20: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_20 = reader.readInt32() }
            var _21: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {_21 = reader.readInt32() }
            var _22: Api.StarGiftBackground?
            if Int(_1!) & Int(1 << 13) != 0 {if let signature = reader.readInt32() {
                _22 = Api.parse(reader, signature: signature) as? Api.StarGiftBackground
            } }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            if !_c12 { return nil }
            if !_c13 { return nil }
            if !_c14 { return nil }
            if !_c15 { return nil }
            if !_c16 { return nil }
            if !_c17 { return nil }
            if !_c18 { return nil }
            if !_c19 { return nil }
            if !_c20 { return nil }
            if !_c21 { return nil }
            if !_c22 { return nil }
            return Api.StarGift.starGift(flags: _1!, id: _2!, sticker: _3!, stars: _4!, availabilityRemains: _5, availabilityTotal: _6, availabilityResale: _7, convertStars: _8!, firstSaleDate: _9, lastSaleDate: _10, upgradeStars: _11, resellMinStars: _12, title: _13, releasedBy: _14, perUserTotal: _15, perUserRemains: _16, lockedUntilDate: _17, auctionSlug: _18, giftsPerRound: _19, auctionStartDate: _20, upgradeVariants: _21, background: _22)
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _8: String?
            if Int(_1!) & Int(1 << 1) != 0 {_8 = parseString(reader) }
            var _9: String?
            if Int(_1!) & Int(1 << 2) != 0 {_9 = parseString(reader) }
            var _10: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: String?
            if Int(_1!) & Int(1 << 3) != 0 {_13 = parseString(reader) }
            var _14: [Api.StarsAmount]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsAmount.self)
            } }
            var _15: Api.Peer?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _16: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {_16 = reader.readInt64() }
            var _17: String?
            if Int(_1!) & Int(1 << 8) != 0 {_17 = parseString(reader) }
            var _18: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {_18 = reader.readInt64() }
            var _19: Api.Peer?
            if Int(_1!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _20: Api.PeerColor?
            if Int(_1!) & Int(1 << 11) != 0 {if let signature = reader.readInt32() {
                _20 = Api.parse(reader, signature: signature) as? Api.PeerColor
            } }
            var _21: Api.Peer?
            if Int(_1!) & Int(1 << 12) != 0 {if let signature = reader.readInt32() {
                _21 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _22: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {_22 = reader.readInt32() }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            if !_c12 { return nil }
            if !_c13 { return nil }
            if !_c14 { return nil }
            if !_c15 { return nil }
            if !_c16 { return nil }
            if !_c17 { return nil }
            if !_c18 { return nil }
            if !_c19 { return nil }
            if !_c20 { return nil }
            if !_c21 { return nil }
            if !_c22 { return nil }
            return Api.StarGift.starGiftUnique(flags: _1!, id: _2!, giftId: _3!, title: _4!, slug: _5!, num: _6!, ownerId: _7, ownerName: _8, ownerAddress: _9, attributes: _10!, availabilityIssued: _11!, availabilityTotal: _12!, giftAddress: _13, resellAmount: _14, releasedBy: _15, valueAmount: _16, valueCurrency: _17, valueUsdAmount: _18, themePeer: _19, peerColor: _20, hostId: _21, offerMinStars: _22)
        }
    
    }
}
public extension Api {
    enum StarGiftActiveAuctionState: TypeConstructorDescription {
        case starGiftActiveAuctionState(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftActiveAuctionState(let gift, let state, let userState):
                    if boxed {
                        buffer.appendInt32(-753154979)
                    }
                    gift.serialize(buffer, true)
                    state.serialize(buffer, true)
                    userState.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftActiveAuctionState(let gift, let state, let userState):
                return ("starGiftActiveAuctionState", [("gift", gift as Any), ("state", state as Any), ("userState", userState as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.StarGiftActiveAuctionState.starGiftActiveAuctionState(gift: _1!, state: _2!, userState: _3!)
        }
    
    }
}
public extension Api {
    enum StarGiftAttribute: TypeConstructorDescription {
        case starGiftAttributeBackdrop(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarityPermille: Int32)
        case starGiftAttributeModel(name: String, document: Api.Document, rarityPermille: Int32)
        case starGiftAttributeOriginalDetails(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?)
        case starGiftAttributePattern(name: String, document: Api.Document, rarityPermille: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAttributeBackdrop(let name, let backdropId, let centerColor, let edgeColor, let patternColor, let textColor, let rarityPermille):
                    if boxed {
                        buffer.appendInt32(-650279524)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeInt32(backdropId, buffer: buffer, boxed: false)
                    serializeInt32(centerColor, buffer: buffer, boxed: false)
                    serializeInt32(edgeColor, buffer: buffer, boxed: false)
                    serializeInt32(patternColor, buffer: buffer, boxed: false)
                    serializeInt32(textColor, buffer: buffer, boxed: false)
                    serializeInt32(rarityPermille, buffer: buffer, boxed: false)
                    break
                case .starGiftAttributeModel(let name, let document, let rarityPermille):
                    if boxed {
                        buffer.appendInt32(970559507)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeInt32(rarityPermille, buffer: buffer, boxed: false)
                    break
                case .starGiftAttributeOriginalDetails(let flags, let senderId, let recipientId, let date, let message):
                    if boxed {
                        buffer.appendInt32(-524291476)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {senderId!.serialize(buffer, true)}
                    recipientId.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    break
                case .starGiftAttributePattern(let name, let document, let rarityPermille):
                    if boxed {
                        buffer.appendInt32(330104601)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeInt32(rarityPermille, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAttributeBackdrop(let name, let backdropId, let centerColor, let edgeColor, let patternColor, let textColor, let rarityPermille):
                return ("starGiftAttributeBackdrop", [("name", name as Any), ("backdropId", backdropId as Any), ("centerColor", centerColor as Any), ("edgeColor", edgeColor as Any), ("patternColor", patternColor as Any), ("textColor", textColor as Any), ("rarityPermille", rarityPermille as Any)])
                case .starGiftAttributeModel(let name, let document, let rarityPermille):
                return ("starGiftAttributeModel", [("name", name as Any), ("document", document as Any), ("rarityPermille", rarityPermille as Any)])
                case .starGiftAttributeOriginalDetails(let flags, let senderId, let recipientId, let date, let message):
                return ("starGiftAttributeOriginalDetails", [("flags", flags as Any), ("senderId", senderId as Any), ("recipientId", recipientId as Any), ("date", date as Any), ("message", message as Any)])
                case .starGiftAttributePattern(let name, let document, let rarityPermille):
                return ("starGiftAttributePattern", [("name", name as Any), ("document", document as Any), ("rarityPermille", rarityPermille as Any)])
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
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            return Api.StarGiftAttribute.starGiftAttributeBackdrop(name: _1!, backdropId: _2!, centerColor: _3!, edgeColor: _4!, patternColor: _5!, textColor: _6!, rarityPermille: _7!)
        }
        public static func parse_starGiftAttributeModel(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.StarGiftAttribute.starGiftAttributeModel(name: _1!, document: _2!, rarityPermille: _3!)
        }
        public static func parse_starGiftAttributeOriginalDetails(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.StarGiftAttribute.starGiftAttributeOriginalDetails(flags: _1!, senderId: _2, recipientId: _3!, date: _4!, message: _5)
        }
        public static func parse_starGiftAttributePattern(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.StarGiftAttribute.starGiftAttributePattern(name: _1!, document: _2!, rarityPermille: _3!)
        }
    
    }
}
public extension Api {
    enum StarGiftAttributeCounter: TypeConstructorDescription {
        case starGiftAttributeCounter(attribute: Api.StarGiftAttributeId, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAttributeCounter(let attribute, let count):
                    if boxed {
                        buffer.appendInt32(783398488)
                    }
                    attribute.serialize(buffer, true)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAttributeCounter(let attribute, let count):
                return ("starGiftAttributeCounter", [("attribute", attribute as Any), ("count", count as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.StarGiftAttributeCounter.starGiftAttributeCounter(attribute: _1!, count: _2!)
        }
    
    }
}
public extension Api {
    enum StarGiftAttributeId: TypeConstructorDescription {
        case starGiftAttributeIdBackdrop(backdropId: Int32)
        case starGiftAttributeIdModel(documentId: Int64)
        case starGiftAttributeIdPattern(documentId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAttributeIdBackdrop(let backdropId):
                    if boxed {
                        buffer.appendInt32(520210263)
                    }
                    serializeInt32(backdropId, buffer: buffer, boxed: false)
                    break
                case .starGiftAttributeIdModel(let documentId):
                    if boxed {
                        buffer.appendInt32(1219145276)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    break
                case .starGiftAttributeIdPattern(let documentId):
                    if boxed {
                        buffer.appendInt32(1242965043)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAttributeIdBackdrop(let backdropId):
                return ("starGiftAttributeIdBackdrop", [("backdropId", backdropId as Any)])
                case .starGiftAttributeIdModel(let documentId):
                return ("starGiftAttributeIdModel", [("documentId", documentId as Any)])
                case .starGiftAttributeIdPattern(let documentId):
                return ("starGiftAttributeIdPattern", [("documentId", documentId as Any)])
    }
    }
    
        public static func parse_starGiftAttributeIdBackdrop(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.StarGiftAttributeId.starGiftAttributeIdBackdrop(backdropId: _1!)
        }
        public static func parse_starGiftAttributeIdModel(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.StarGiftAttributeId.starGiftAttributeIdModel(documentId: _1!)
        }
        public static func parse_starGiftAttributeIdPattern(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.StarGiftAttributeId.starGiftAttributeIdPattern(documentId: _1!)
        }
    
    }
}
public extension Api {
    enum StarGiftAuctionAcquiredGift: TypeConstructorDescription {
        case starGiftAuctionAcquiredGift(flags: Int32, peer: Api.Peer, date: Int32, bidAmount: Int64, round: Int32, pos: Int32, message: Api.TextWithEntities?, giftNum: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAuctionAcquiredGift(let flags, let peer, let date, let bidAmount, let round, let pos, let message, let giftNum):
                    if boxed {
                        buffer.appendInt32(1118831432)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(bidAmount, buffer: buffer, boxed: false)
                    serializeInt32(round, buffer: buffer, boxed: false)
                    serializeInt32(pos, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(giftNum!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAuctionAcquiredGift(let flags, let peer, let date, let bidAmount, let round, let pos, let message, let giftNum):
                return ("starGiftAuctionAcquiredGift", [("flags", flags as Any), ("peer", peer as Any), ("date", date as Any), ("bidAmount", bidAmount as Any), ("round", round as Any), ("pos", pos as Any), ("message", message as Any), ("giftNum", giftNum as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_8 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            return Api.StarGiftAuctionAcquiredGift.starGiftAuctionAcquiredGift(flags: _1!, peer: _2!, date: _3!, bidAmount: _4!, round: _5!, pos: _6!, message: _7, giftNum: _8)
        }
    
    }
}
public extension Api {
    enum StarGiftAuctionRound: TypeConstructorDescription {
        case starGiftAuctionRound(num: Int32, duration: Int32)
        case starGiftAuctionRoundExtendable(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAuctionRound(let num, let duration):
                    if boxed {
                        buffer.appendInt32(984483112)
                    }
                    serializeInt32(num, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    break
                case .starGiftAuctionRoundExtendable(let num, let duration, let extendTop, let extendWindow):
                    if boxed {
                        buffer.appendInt32(178266597)
                    }
                    serializeInt32(num, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeInt32(extendTop, buffer: buffer, boxed: false)
                    serializeInt32(extendWindow, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAuctionRound(let num, let duration):
                return ("starGiftAuctionRound", [("num", num as Any), ("duration", duration as Any)])
                case .starGiftAuctionRoundExtendable(let num, let duration, let extendTop, let extendWindow):
                return ("starGiftAuctionRoundExtendable", [("num", num as Any), ("duration", duration as Any), ("extendTop", extendTop as Any), ("extendWindow", extendWindow as Any)])
    }
    }
    
        public static func parse_starGiftAuctionRound(_ reader: BufferReader) -> StarGiftAuctionRound? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.StarGiftAuctionRound.starGiftAuctionRound(num: _1!, duration: _2!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.StarGiftAuctionRound.starGiftAuctionRoundExtendable(num: _1!, duration: _2!, extendTop: _3!, extendWindow: _4!)
        }
    
    }
}
public extension Api {
    enum StarGiftAuctionState: TypeConstructorDescription {
        case starGiftAuctionState(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [Api.AuctionBidLevel], topBidders: [Int64], nextRoundAt: Int32, lastGiftNum: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Api.StarGiftAuctionRound])
        case starGiftAuctionStateFinished(flags: Int32, startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?)
        case starGiftAuctionStateNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAuctionState(let version, let startDate, let endDate, let minBidAmount, let bidLevels, let topBidders, let nextRoundAt, let lastGiftNum, let giftsLeft, let currentRound, let totalRounds, let rounds):
                    if boxed {
                        buffer.appendInt32(1998212710)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    serializeInt32(endDate, buffer: buffer, boxed: false)
                    serializeInt64(minBidAmount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(bidLevels.count))
                    for item in bidLevels {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topBidders.count))
                    for item in topBidders {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(nextRoundAt, buffer: buffer, boxed: false)
                    serializeInt32(lastGiftNum, buffer: buffer, boxed: false)
                    serializeInt32(giftsLeft, buffer: buffer, boxed: false)
                    serializeInt32(currentRound, buffer: buffer, boxed: false)
                    serializeInt32(totalRounds, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rounds.count))
                    for item in rounds {
                        item.serialize(buffer, true)
                    }
                    break
                case .starGiftAuctionStateFinished(let flags, let startDate, let endDate, let averagePrice, let listedCount, let fragmentListedCount, let fragmentListedUrl):
                    if boxed {
                        buffer.appendInt32(-1758614593)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    serializeInt32(endDate, buffer: buffer, boxed: false)
                    serializeInt64(averagePrice, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(listedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(fragmentListedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(fragmentListedUrl!, buffer: buffer, boxed: false)}
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
                case .starGiftAuctionState(let version, let startDate, let endDate, let minBidAmount, let bidLevels, let topBidders, let nextRoundAt, let lastGiftNum, let giftsLeft, let currentRound, let totalRounds, let rounds):
                return ("starGiftAuctionState", [("version", version as Any), ("startDate", startDate as Any), ("endDate", endDate as Any), ("minBidAmount", minBidAmount as Any), ("bidLevels", bidLevels as Any), ("topBidders", topBidders as Any), ("nextRoundAt", nextRoundAt as Any), ("lastGiftNum", lastGiftNum as Any), ("giftsLeft", giftsLeft as Any), ("currentRound", currentRound as Any), ("totalRounds", totalRounds as Any), ("rounds", rounds as Any)])
                case .starGiftAuctionStateFinished(let flags, let startDate, let endDate, let averagePrice, let listedCount, let fragmentListedCount, let fragmentListedUrl):
                return ("starGiftAuctionStateFinished", [("flags", flags as Any), ("startDate", startDate as Any), ("endDate", endDate as Any), ("averagePrice", averagePrice as Any), ("listedCount", listedCount as Any), ("fragmentListedCount", fragmentListedCount as Any), ("fragmentListedUrl", fragmentListedUrl as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            if !_c12 { return nil }
            return Api.StarGiftAuctionState.starGiftAuctionState(version: _1!, startDate: _2!, endDate: _3!, minBidAmount: _4!, bidLevels: _5!, topBidders: _6!, nextRoundAt: _7!, lastGiftNum: _8!, giftsLeft: _9!, currentRound: _10!, totalRounds: _11!, rounds: _12!)
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
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            return Api.StarGiftAuctionState.starGiftAuctionStateFinished(flags: _1!, startDate: _2!, endDate: _3!, averagePrice: _4!, listedCount: _5, fragmentListedCount: _6, fragmentListedUrl: _7)
        }
        public static func parse_starGiftAuctionStateNotModified(_ reader: BufferReader) -> StarGiftAuctionState? {
            return Api.StarGiftAuctionState.starGiftAuctionStateNotModified
        }
    
    }
}
public extension Api {
    enum StarGiftAuctionUserState: TypeConstructorDescription {
        case starGiftAuctionUserState(flags: Int32, bidAmount: Int64?, bidDate: Int32?, minBidAmount: Int64?, bidPeer: Api.Peer?, acquiredCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAuctionUserState(let flags, let bidAmount, let bidDate, let minBidAmount, let bidPeer, let acquiredCount):
                    if boxed {
                        buffer.appendInt32(787403204)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(bidAmount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(bidDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(minBidAmount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {bidPeer!.serialize(buffer, true)}
                    serializeInt32(acquiredCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAuctionUserState(let flags, let bidAmount, let bidDate, let minBidAmount, let bidPeer, let acquiredCount):
                return ("starGiftAuctionUserState", [("flags", flags as Any), ("bidAmount", bidAmount as Any), ("bidDate", bidDate as Any), ("minBidAmount", minBidAmount as Any), ("bidPeer", bidPeer as Any), ("acquiredCount", acquiredCount as Any)])
    }
    }
    
        public static func parse_starGiftAuctionUserState(_ reader: BufferReader) -> StarGiftAuctionUserState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt64() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt64() }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.StarGiftAuctionUserState.starGiftAuctionUserState(flags: _1!, bidAmount: _2, bidDate: _3, minBidAmount: _4, bidPeer: _5, acquiredCount: _6!)
        }
    
    }
}
public extension Api {
    enum StarGiftBackground: TypeConstructorDescription {
        case starGiftBackground(centerColor: Int32, edgeColor: Int32, textColor: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftBackground(let centerColor, let edgeColor, let textColor):
                    if boxed {
                        buffer.appendInt32(-1342872680)
                    }
                    serializeInt32(centerColor, buffer: buffer, boxed: false)
                    serializeInt32(edgeColor, buffer: buffer, boxed: false)
                    serializeInt32(textColor, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftBackground(let centerColor, let edgeColor, let textColor):
                return ("starGiftBackground", [("centerColor", centerColor as Any), ("edgeColor", edgeColor as Any), ("textColor", textColor as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.StarGiftBackground.starGiftBackground(centerColor: _1!, edgeColor: _2!, textColor: _3!)
        }
    
    }
}
public extension Api {
    enum StarGiftCollection: TypeConstructorDescription {
        case starGiftCollection(flags: Int32, collectionId: Int32, title: String, icon: Api.Document?, giftsCount: Int32, hash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftCollection(let flags, let collectionId, let title, let icon, let giftsCount, let hash):
                    if boxed {
                        buffer.appendInt32(-1653926992)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(collectionId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {icon!.serialize(buffer, true)}
                    serializeInt32(giftsCount, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftCollection(let flags, let collectionId, let title, let icon, let giftsCount, let hash):
                return ("starGiftCollection", [("flags", flags as Any), ("collectionId", collectionId as Any), ("title", title as Any), ("icon", icon as Any), ("giftsCount", giftsCount as Any), ("hash", hash as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Document
            } }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.StarGiftCollection.starGiftCollection(flags: _1!, collectionId: _2!, title: _3!, icon: _4, giftsCount: _5!, hash: _6!)
        }
    
    }
}
public extension Api {
    enum StarGiftUpgradePrice: TypeConstructorDescription {
        case starGiftUpgradePrice(date: Int32, upgradeStars: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftUpgradePrice(let date, let upgradeStars):
                    if boxed {
                        buffer.appendInt32(-1712704739)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(upgradeStars, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftUpgradePrice(let date, let upgradeStars):
                return ("starGiftUpgradePrice", [("date", date as Any), ("upgradeStars", upgradeStars as Any)])
    }
    }
    
        public static func parse_starGiftUpgradePrice(_ reader: BufferReader) -> StarGiftUpgradePrice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.StarGiftUpgradePrice.starGiftUpgradePrice(date: _1!, upgradeStars: _2!)
        }
    
    }
}
public extension Api {
    enum StarRefProgram: TypeConstructorDescription {
        case starRefProgram(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starRefProgram(let flags, let botId, let commissionPermille, let durationMonths, let endDate, let dailyRevenuePerUser):
                    if boxed {
                        buffer.appendInt32(-586389774)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeInt32(commissionPermille, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(durationMonths!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(endDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {dailyRevenuePerUser!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starRefProgram(let flags, let botId, let commissionPermille, let durationMonths, let endDate, let dailyRevenuePerUser):
                return ("starRefProgram", [("flags", flags as Any), ("botId", botId as Any), ("commissionPermille", commissionPermille as Any), ("durationMonths", durationMonths as Any), ("endDate", endDate as Any), ("dailyRevenuePerUser", dailyRevenuePerUser as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            var _6: Api.StarsAmount?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.StarRefProgram.starRefProgram(flags: _1!, botId: _2!, commissionPermille: _3!, durationMonths: _4, endDate: _5, dailyRevenuePerUser: _6)
        }
    
    }
}
public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        case starsAmount(amount: Int64, nanos: Int32)
        case starsTonAmount(amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsAmount(let amount, let nanos):
                    if boxed {
                        buffer.appendInt32(-1145654109)
                    }
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    serializeInt32(nanos, buffer: buffer, boxed: false)
                    break
                case .starsTonAmount(let amount):
                    if boxed {
                        buffer.appendInt32(1957618656)
                    }
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsAmount(let amount, let nanos):
                return ("starsAmount", [("amount", amount as Any), ("nanos", nanos as Any)])
                case .starsTonAmount(let amount):
                return ("starsTonAmount", [("amount", amount as Any)])
    }
    }
    
        public static func parse_starsAmount(_ reader: BufferReader) -> StarsAmount? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.StarsAmount.starsAmount(amount: _1!, nanos: _2!)
        }
        public static func parse_starsTonAmount(_ reader: BufferReader) -> StarsAmount? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.StarsAmount.starsTonAmount(amount: _1!)
        }
    
    }
}
public extension Api {
    enum StarsGiftOption: TypeConstructorDescription {
        case starsGiftOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiftOption(let flags, let stars, let storeProduct, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(1577421297)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiftOption(let flags, let stars, let storeProduct, let currency, let amount):
                return ("starsGiftOption", [("flags", flags as Any), ("stars", stars as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_starsGiftOption(_ reader: BufferReader) -> StarsGiftOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.StarsGiftOption.starsGiftOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!)
        }
    
    }
}
public extension Api {
    enum StarsGiveawayOption: TypeConstructorDescription {
        case starsGiveawayOption(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiveawayOption(let flags, let stars, let yearlyBoosts, let storeProduct, let currency, let amount, let winners):
                    if boxed {
                        buffer.appendInt32(-1798404822)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeInt32(yearlyBoosts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(winners.count))
                    for item in winners {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiveawayOption(let flags, let stars, let yearlyBoosts, let storeProduct, let currency, let amount, let winners):
                return ("starsGiveawayOption", [("flags", flags as Any), ("stars", stars as Any), ("yearlyBoosts", yearlyBoosts as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any), ("winners", winners as Any)])
    }
    }
    
        public static func parse_starsGiveawayOption(_ reader: BufferReader) -> StarsGiveawayOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: [Api.StarsGiveawayWinnersOption]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsGiveawayWinnersOption.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            return Api.StarsGiveawayOption.starsGiveawayOption(flags: _1!, stars: _2!, yearlyBoosts: _3!, storeProduct: _4, currency: _5!, amount: _6!, winners: _7!)
        }
    
    }
}
public extension Api {
    enum StarsGiveawayWinnersOption: TypeConstructorDescription {
        case starsGiveawayWinnersOption(flags: Int32, users: Int32, perUserStars: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiveawayWinnersOption(let flags, let users, let perUserStars):
                    if boxed {
                        buffer.appendInt32(1411605001)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(users, buffer: buffer, boxed: false)
                    serializeInt64(perUserStars, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiveawayWinnersOption(let flags, let users, let perUserStars):
                return ("starsGiveawayWinnersOption", [("flags", flags as Any), ("users", users as Any), ("perUserStars", perUserStars as Any)])
    }
    }
    
        public static func parse_starsGiveawayWinnersOption(_ reader: BufferReader) -> StarsGiveawayWinnersOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.StarsGiveawayWinnersOption.starsGiveawayWinnersOption(flags: _1!, users: _2!, perUserStars: _3!)
        }
    
    }
}
