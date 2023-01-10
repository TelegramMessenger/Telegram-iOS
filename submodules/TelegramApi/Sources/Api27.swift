public extension Api.payments {
    enum ValidatedRequestedInfo: TypeConstructorDescription {
        case validatedRequestedInfo(flags: Int32, id: String?, shippingOptions: [Api.ShippingOption]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .validatedRequestedInfo(let flags, let id, let shippingOptions):
                    if boxed {
                        buffer.appendInt32(-784000893)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(id!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(shippingOptions!.count))
                    for item in shippingOptions! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .validatedRequestedInfo(let flags, let id, let shippingOptions):
                return ("validatedRequestedInfo", [("flags", String(describing: flags)), ("id", String(describing: id)), ("shippingOptions", String(describing: shippingOptions))])
    }
    }
    
        public static func parse_validatedRequestedInfo(_ reader: BufferReader) -> ValidatedRequestedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: [Api.ShippingOption]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ShippingOption.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.ValidatedRequestedInfo.validatedRequestedInfo(flags: _1!, id: _2, shippingOptions: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum ExportedGroupCallInvite: TypeConstructorDescription {
        case exportedGroupCallInvite(link: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedGroupCallInvite(let link):
                    if boxed {
                        buffer.appendInt32(541839704)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedGroupCallInvite(let link):
                return ("exportedGroupCallInvite", [("link", String(describing: link))])
    }
    }
    
        public static func parse_exportedGroupCallInvite(_ reader: BufferReader) -> ExportedGroupCallInvite? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.ExportedGroupCallInvite.exportedGroupCallInvite(link: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(call: Api.GroupCall, participants: [Api.GroupCallParticipant], participantsNextOffset: String, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCall(let call, let participants, let participantsNextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1636664659)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(participantsNextOffset, buffer: buffer, boxed: false)
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
                case .groupCall(let call, let participants, let participantsNextOffset, let chats, let users):
                return ("groupCall", [("call", String(describing: call)), ("participants", String(describing: participants)), ("participantsNextOffset", String(describing: participantsNextOffset)), ("chats", String(describing: chats)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Api.GroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCall
            }
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
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
                return Api.phone.GroupCall.groupCall(call: _1!, participants: _2!, participantsNextOffset: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStreamChannels: TypeConstructorDescription {
        case groupCallStreamChannels(channels: [Api.GroupCallStreamChannel])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamChannels(let channels):
                    if boxed {
                        buffer.appendInt32(-790330702)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(channels.count))
                    for item in channels {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamChannels(let channels):
                return ("groupCallStreamChannels", [("channels", String(describing: channels))])
    }
    }
    
        public static func parse_groupCallStreamChannels(_ reader: BufferReader) -> GroupCallStreamChannels? {
            var _1: [Api.GroupCallStreamChannel]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallStreamChannel.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.GroupCallStreamChannels.groupCallStreamChannels(channels: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStreamRtmpUrl: TypeConstructorDescription {
        case groupCallStreamRtmpUrl(url: String, key: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamRtmpUrl(let url, let key):
                    if boxed {
                        buffer.appendInt32(767505458)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamRtmpUrl(let url, let key):
                return ("groupCallStreamRtmpUrl", [("url", String(describing: url)), ("key", String(describing: key))])
    }
    }
    
        public static func parse_groupCallStreamRtmpUrl(_ reader: BufferReader) -> GroupCallStreamRtmpUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.GroupCallStreamRtmpUrl.groupCallStreamRtmpUrl(url: _1!, key: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription {
        case groupParticipants(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                    if boxed {
                        buffer.appendInt32(-193506890)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(nextOffset, buffer: buffer, boxed: false)
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
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                return ("groupParticipants", [("count", String(describing: count)), ("participants", String(describing: participants)), ("nextOffset", String(describing: nextOffset)), ("chats", String(describing: chats)), ("users", String(describing: users)), ("version", String(describing: version))])
    }
    }
    
        public static func parse_groupParticipants(_ reader: BufferReader) -> GroupParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
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
                return Api.phone.GroupParticipants.groupParticipants(count: _1!, participants: _2!, nextOffset: _3!, chats: _4!, users: _5!, version: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription {
        case joinAsPeers(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .joinAsPeers(let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1343921601)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
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
                case .joinAsPeers(let peers, let chats, let users):
                return ("joinAsPeers", [("peers", String(describing: peers)), ("chats", String(describing: chats)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_joinAsPeers(_ reader: BufferReader) -> JoinAsPeers? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
                return Api.phone.JoinAsPeers.joinAsPeers(peers: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription {
        case phoneCall(phoneCall: Api.PhoneCall, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCall(let phoneCall, let users):
                    if boxed {
                        buffer.appendInt32(-326966976)
                    }
                    phoneCall.serialize(buffer, true)
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
                case .phoneCall(let phoneCall, let users):
                return ("phoneCall", [("phoneCall", String(describing: phoneCall)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.PhoneCall.phoneCall(phoneCall: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription {
        case photo(photo: Api.Photo, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photo(let photo, let users):
                    if boxed {
                        buffer.appendInt32(539045032)
                    }
                    photo.serialize(buffer, true)
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
                case .photo(let photo, let users):
                return ("photo", [("photo", String(describing: photo)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photo.photo(photo: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription {
        case photos(photos: [Api.Photo], users: [Api.User])
        case photosSlice(count: Int32, photos: [Api.Photo], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photos(let photos, let users):
                    if boxed {
                        buffer.appendInt32(-1916114267)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .photosSlice(let count, let photos, let users):
                    if boxed {
                        buffer.appendInt32(352657236)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
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
                case .photos(let photos, let users):
                return ("photos", [("photos", String(describing: photos)), ("users", String(describing: users))])
                case .photosSlice(let count, let photos, let users):
                return ("photosSlice", [("count", String(describing: count)), ("photos", String(describing: photos)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_photos(_ reader: BufferReader) -> Photos? {
            var _1: [Api.Photo]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photos.photos(photos: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Photo]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.photos.Photos.photosSlice(count: _1!, photos: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription {
        case broadcastStats(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, recentMessageInteractions: [Api.MessageInteractionCounters])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let recentMessageInteractions):
                    if boxed {
                        buffer.appendInt32(-1107852396)
                    }
                    period.serialize(buffer, true)
                    followers.serialize(buffer, true)
                    viewsPerPost.serialize(buffer, true)
                    sharesPerPost.serialize(buffer, true)
                    enabledNotifications.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    followersGraph.serialize(buffer, true)
                    muteGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    interactionsGraph.serialize(buffer, true)
                    ivInteractionsGraph.serialize(buffer, true)
                    viewsBySourceGraph.serialize(buffer, true)
                    newFollowersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentMessageInteractions.count))
                    for item in recentMessageInteractions {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let recentMessageInteractions):
                return ("broadcastStats", [("period", String(describing: period)), ("followers", String(describing: followers)), ("viewsPerPost", String(describing: viewsPerPost)), ("sharesPerPost", String(describing: sharesPerPost)), ("enabledNotifications", String(describing: enabledNotifications)), ("growthGraph", String(describing: growthGraph)), ("followersGraph", String(describing: followersGraph)), ("muteGraph", String(describing: muteGraph)), ("topHoursGraph", String(describing: topHoursGraph)), ("interactionsGraph", String(describing: interactionsGraph)), ("ivInteractionsGraph", String(describing: ivInteractionsGraph)), ("viewsBySourceGraph", String(describing: viewsBySourceGraph)), ("newFollowersBySourceGraph", String(describing: newFollowersBySourceGraph)), ("languagesGraph", String(describing: languagesGraph)), ("recentMessageInteractions", String(describing: recentMessageInteractions))])
    }
    }
    
        public static func parse_broadcastStats(_ reader: BufferReader) -> BroadcastStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsPercentValue?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            }
            var _6: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _7: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _8: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _9: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _15: [Api.MessageInteractionCounters]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageInteractionCounters.self)
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
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.stats.BroadcastStats.broadcastStats(period: _1!, followers: _2!, viewsPerPost: _3!, sharesPerPost: _4!, enabledNotifications: _5!, growthGraph: _6!, followersGraph: _7!, muteGraph: _8!, topHoursGraph: _9!, interactionsGraph: _10!, ivInteractionsGraph: _11!, viewsBySourceGraph: _12!, newFollowersBySourceGraph: _13!, languagesGraph: _14!, recentMessageInteractions: _15!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription {
        case megagroupStats(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                    if boxed {
                        buffer.appendInt32(-276825834)
                    }
                    period.serialize(buffer, true)
                    members.serialize(buffer, true)
                    messages.serialize(buffer, true)
                    viewers.serialize(buffer, true)
                    posters.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    membersGraph.serialize(buffer, true)
                    newMembersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    messagesGraph.serialize(buffer, true)
                    actionsGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    weekdaysGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topPosters.count))
                    for item in topPosters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topAdmins.count))
                    for item in topAdmins {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topInviters.count))
                    for item in topInviters {
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
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                return ("megagroupStats", [("period", String(describing: period)), ("members", String(describing: members)), ("messages", String(describing: messages)), ("viewers", String(describing: viewers)), ("posters", String(describing: posters)), ("growthGraph", String(describing: growthGraph)), ("membersGraph", String(describing: membersGraph)), ("newMembersBySourceGraph", String(describing: newMembersBySourceGraph)), ("languagesGraph", String(describing: languagesGraph)), ("messagesGraph", String(describing: messagesGraph)), ("actionsGraph", String(describing: actionsGraph)), ("topHoursGraph", String(describing: topHoursGraph)), ("weekdaysGraph", String(describing: weekdaysGraph)), ("topPosters", String(describing: topPosters)), ("topAdmins", String(describing: topAdmins)), ("topInviters", String(describing: topInviters)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_megagroupStats(_ reader: BufferReader) -> MegagroupStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _7: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _8: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _9: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: [Api.StatsGroupTopPoster]?
            if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopPoster.self)
            }
            var _15: [Api.StatsGroupTopAdmin]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopAdmin.self)
            }
            var _16: [Api.StatsGroupTopInviter]?
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopInviter.self)
            }
            var _17: [Api.User]?
            if let _ = reader.readInt32() {
                _17 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
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
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.stats.MegagroupStats.megagroupStats(period: _1!, members: _2!, messages: _3!, viewers: _4!, posters: _5!, growthGraph: _6!, membersGraph: _7!, newMembersBySourceGraph: _8!, languagesGraph: _9!, messagesGraph: _10!, actionsGraph: _11!, topHoursGraph: _12!, weekdaysGraph: _13!, topPosters: _14!, topAdmins: _15!, topInviters: _16!, users: _17!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription {
        case messageStats(viewsGraph: Api.StatsGraph)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageStats(let viewsGraph):
                    if boxed {
                        buffer.appendInt32(-1986399595)
                    }
                    viewsGraph.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageStats(let viewsGraph):
                return ("messageStats", [("viewsGraph", String(describing: viewsGraph))])
    }
    }
    
        public static func parse_messageStats(_ reader: BufferReader) -> MessageStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.stats.MessageStats.messageStats(viewsGraph: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription {
        case suggestedShortName(shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2046910401)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedShortName(let shortName):
                return ("suggestedShortName", [("shortName", String(describing: shortName))])
    }
    }
    
        public static func parse_suggestedShortName(_ reader: BufferReader) -> SuggestedShortName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.stickers.SuggestedShortName.suggestedShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.storage {
    enum FileType: TypeConstructorDescription {
        case fileGif
        case fileJpeg
        case fileMov
        case fileMp3
        case fileMp4
        case filePartial
        case filePdf
        case filePng
        case fileUnknown
        case fileWebp
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileGif:
                    if boxed {
                        buffer.appendInt32(-891180321)
                    }
                    
                    break
                case .fileJpeg:
                    if boxed {
                        buffer.appendInt32(8322574)
                    }
                    
                    break
                case .fileMov:
                    if boxed {
                        buffer.appendInt32(1258941372)
                    }
                    
                    break
                case .fileMp3:
                    if boxed {
                        buffer.appendInt32(1384777335)
                    }
                    
                    break
                case .fileMp4:
                    if boxed {
                        buffer.appendInt32(-1278304028)
                    }
                    
                    break
                case .filePartial:
                    if boxed {
                        buffer.appendInt32(1086091090)
                    }
                    
                    break
                case .filePdf:
                    if boxed {
                        buffer.appendInt32(-1373745011)
                    }
                    
                    break
                case .filePng:
                    if boxed {
                        buffer.appendInt32(172975040)
                    }
                    
                    break
                case .fileUnknown:
                    if boxed {
                        buffer.appendInt32(-1432995067)
                    }
                    
                    break
                case .fileWebp:
                    if boxed {
                        buffer.appendInt32(276907596)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileGif:
                return ("fileGif", [])
                case .fileJpeg:
                return ("fileJpeg", [])
                case .fileMov:
                return ("fileMov", [])
                case .fileMp3:
                return ("fileMp3", [])
                case .fileMp4:
                return ("fileMp4", [])
                case .filePartial:
                return ("filePartial", [])
                case .filePdf:
                return ("filePdf", [])
                case .filePng:
                return ("filePng", [])
                case .fileUnknown:
                return ("fileUnknown", [])
                case .fileWebp:
                return ("fileWebp", [])
    }
    }
    
        public static func parse_fileGif(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileGif
        }
        public static func parse_fileJpeg(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileJpeg
        }
        public static func parse_fileMov(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMov
        }
        public static func parse_fileMp3(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp3
        }
        public static func parse_fileMp4(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp4
        }
        public static func parse_filePartial(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePartial
        }
        public static func parse_filePdf(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePdf
        }
        public static func parse_filePng(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePng
        }
        public static func parse_fileUnknown(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileUnknown
        }
        public static func parse_fileWebp(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileWebp
        }
    
    }
}
public extension Api.updates {
    enum ChannelDifference: TypeConstructorDescription {
        case channelDifference(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User])
        case channelDifferenceEmpty(flags: Int32, pts: Int32, timeout: Int32?)
        case channelDifferenceTooLong(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                    if boxed {
                        buffer.appendInt32(543450958)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                    if boxed {
                        buffer.appendInt32(1041346555)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    break
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1531132162)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    dialog.serialize(buffer, true)
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
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                return ("channelDifference", [("flags", String(describing: flags)), ("pts", String(describing: pts)), ("timeout", String(describing: timeout)), ("newMessages", String(describing: newMessages)), ("otherUpdates", String(describing: otherUpdates)), ("chats", String(describing: chats)), ("users", String(describing: users))])
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                return ("channelDifferenceEmpty", [("flags", String(describing: flags)), ("pts", String(describing: pts)), ("timeout", String(describing: timeout))])
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                return ("channelDifferenceTooLong", [("flags", String(describing: flags)), ("timeout", String(describing: timeout)), ("dialog", String(describing: dialog)), ("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_channelDifference(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Update]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.updates.ChannelDifference.channelDifference(flags: _1!, pts: _2!, timeout: _3, newMessages: _4!, otherUpdates: _5!, chats: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceEmpty(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.updates.ChannelDifference.channelDifferenceEmpty(flags: _1!, pts: _2!, timeout: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceTooLong(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Api.Dialog?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Dialog
            }
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
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.ChannelDifference.channelDifferenceTooLong(flags: _1!, timeout: _2, dialog: _3!, messages: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.updates {
    enum Difference: TypeConstructorDescription {
        case difference(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], state: Api.updates.State)
        case differenceEmpty(date: Int32, seq: Int32)
        case differenceSlice(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], intermediateState: Api.updates.State)
        case differenceTooLong(pts: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .difference(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let state):
                    if boxed {
                        buffer.appendInt32(16030880)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newEncryptedMessages.count))
                    for item in newEncryptedMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                case .differenceEmpty(let date, let seq):
                    if boxed {
                        buffer.appendInt32(1567990072)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .differenceSlice(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let intermediateState):
                    if boxed {
                        buffer.appendInt32(-1459938943)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newEncryptedMessages.count))
                    for item in newEncryptedMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                    intermediateState.serialize(buffer, true)
                    break
                case .differenceTooLong(let pts):
                    if boxed {
                        buffer.appendInt32(1258196845)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .difference(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let state):
                return ("difference", [("newMessages", String(describing: newMessages)), ("newEncryptedMessages", String(describing: newEncryptedMessages)), ("otherUpdates", String(describing: otherUpdates)), ("chats", String(describing: chats)), ("users", String(describing: users)), ("state", String(describing: state))])
                case .differenceEmpty(let date, let seq):
                return ("differenceEmpty", [("date", String(describing: date)), ("seq", String(describing: seq))])
                case .differenceSlice(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let intermediateState):
                return ("differenceSlice", [("newMessages", String(describing: newMessages)), ("newEncryptedMessages", String(describing: newEncryptedMessages)), ("otherUpdates", String(describing: otherUpdates)), ("chats", String(describing: chats)), ("users", String(describing: users)), ("intermediateState", String(describing: intermediateState))])
                case .differenceTooLong(let pts):
                return ("differenceTooLong", [("pts", String(describing: pts))])
    }
    }
    
        public static func parse_difference(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.difference(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, state: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceEmpty(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.updates.Difference.differenceEmpty(date: _1!, seq: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceSlice(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.differenceSlice(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, intermediateState: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceTooLong(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.updates.Difference.differenceTooLong(pts: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
