public extension Api {
    enum BusinessIntro: TypeConstructorDescription {
        case businessIntro(flags: Int32, title: String, description: String, sticker: Api.Document?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessIntro(let flags, let title, let description, let sticker):
                    if boxed {
                        buffer.appendInt32(1510606445)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {sticker!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessIntro(let flags, let title, let description, let sticker):
                return ("businessIntro", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("sticker", sticker as Any)])
    }
    }
    
        public static func parse_businessIntro(_ reader: BufferReader) -> BusinessIntro? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BusinessIntro.businessIntro(flags: _1!, title: _2!, description: _3!, sticker: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessLocation: TypeConstructorDescription {
        case businessLocation(flags: Int32, geoPoint: Api.GeoPoint?, address: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessLocation(let flags, let geoPoint, let address):
                    if boxed {
                        buffer.appendInt32(-1403249929)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geoPoint!.serialize(buffer, true)}
                    serializeString(address, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessLocation(let flags, let geoPoint, let address):
                return ("businessLocation", [("flags", flags as Any), ("geoPoint", geoPoint as Any), ("address", address as Any)])
    }
    }
    
        public static func parse_businessLocation(_ reader: BufferReader) -> BusinessLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            } }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessLocation.businessLocation(flags: _1!, geoPoint: _2, address: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessRecipients: TypeConstructorDescription {
        case businessRecipients(flags: Int32, users: [Int64]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessRecipients(let flags, let users):
                    if boxed {
                        buffer.appendInt32(554733559)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users!.count))
                    for item in users! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessRecipients(let flags, let users):
                return ("businessRecipients", [("flags", flags as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_businessRecipients(_ reader: BufferReader) -> BusinessRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.BusinessRecipients.businessRecipients(flags: _1!, users: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessWeeklyOpen: TypeConstructorDescription {
        case businessWeeklyOpen(startMinute: Int32, endMinute: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessWeeklyOpen(let startMinute, let endMinute):
                    if boxed {
                        buffer.appendInt32(302717625)
                    }
                    serializeInt32(startMinute, buffer: buffer, boxed: false)
                    serializeInt32(endMinute, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessWeeklyOpen(let startMinute, let endMinute):
                return ("businessWeeklyOpen", [("startMinute", startMinute as Any), ("endMinute", endMinute as Any)])
    }
    }
    
        public static func parse_businessWeeklyOpen(_ reader: BufferReader) -> BusinessWeeklyOpen? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BusinessWeeklyOpen.businessWeeklyOpen(startMinute: _1!, endMinute: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessWorkHours: TypeConstructorDescription {
        case businessWorkHours(flags: Int32, timezoneId: String, weeklyOpen: [Api.BusinessWeeklyOpen])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessWorkHours(let flags, let timezoneId, let weeklyOpen):
                    if boxed {
                        buffer.appendInt32(-1936543592)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(timezoneId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(weeklyOpen.count))
                    for item in weeklyOpen {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessWorkHours(let flags, let timezoneId, let weeklyOpen):
                return ("businessWorkHours", [("flags", flags as Any), ("timezoneId", timezoneId as Any), ("weeklyOpen", weeklyOpen as Any)])
    }
    }
    
        public static func parse_businessWorkHours(_ reader: BufferReader) -> BusinessWorkHours? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.BusinessWeeklyOpen]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BusinessWeeklyOpen.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessWorkHours.businessWorkHours(flags: _1!, timezoneId: _2!, weeklyOpen: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum CdnConfig: TypeConstructorDescription {
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
                return ("cdnConfig", [("publicKeys", publicKeys as Any)])
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
}
public extension Api {
    enum CdnPublicKey: TypeConstructorDescription {
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
                return ("cdnPublicKey", [("dcId", dcId as Any), ("publicKey", publicKey as Any)])
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
}
public extension Api {
    indirect enum ChannelAdminLogEvent: TypeConstructorDescription {
        case channelAdminLogEvent(id: Int64, date: Int32, userId: Int64, action: Api.ChannelAdminLogEventAction)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEvent(let id, let date, let userId, let action):
                    if boxed {
                        buffer.appendInt32(531458253)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEvent(let id, let date, let userId, let action):
                return ("channelAdminLogEvent", [("id", id as Any), ("date", date as Any), ("userId", userId as Any), ("action", action as Any)])
    }
    }
    
        public static func parse_channelAdminLogEvent(_ reader: BufferReader) -> ChannelAdminLogEvent? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
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
}
public extension Api {
    indirect enum ChannelAdminLogEventAction: TypeConstructorDescription {
        case channelAdminLogEventActionChangeAbout(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeAvailableReactions(prevValue: Api.ChatReactions, newValue: Api.ChatReactions)
        case channelAdminLogEventActionChangeEmojiStatus(prevValue: Api.EmojiStatus, newValue: Api.EmojiStatus)
        case channelAdminLogEventActionChangeEmojiStickerSet(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet)
        case channelAdminLogEventActionChangeHistoryTTL(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionChangeLinkedChat(prevValue: Int64, newValue: Int64)
        case channelAdminLogEventActionChangeLocation(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation)
        case channelAdminLogEventActionChangePeerColor(prevValue: Api.PeerColor, newValue: Api.PeerColor)
        case channelAdminLogEventActionChangePhoto(prevPhoto: Api.Photo, newPhoto: Api.Photo)
        case channelAdminLogEventActionChangeProfilePeerColor(prevValue: Api.PeerColor, newValue: Api.PeerColor)
        case channelAdminLogEventActionChangeStickerSet(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet)
        case channelAdminLogEventActionChangeTitle(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsername(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsernames(prevValue: [String], newValue: [String])
        case channelAdminLogEventActionChangeWallpaper(prevValue: Api.WallPaper, newValue: Api.WallPaper)
        case channelAdminLogEventActionCreateTopic(topic: Api.ForumTopic)
        case channelAdminLogEventActionDefaultBannedRights(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights)
        case channelAdminLogEventActionDeleteMessage(message: Api.Message)
        case channelAdminLogEventActionDeleteTopic(topic: Api.ForumTopic)
        case channelAdminLogEventActionDiscardGroupCall(call: Api.InputGroupCall)
        case channelAdminLogEventActionEditMessage(prevMessage: Api.Message, newMessage: Api.Message)
        case channelAdminLogEventActionEditTopic(prevTopic: Api.ForumTopic, newTopic: Api.ForumTopic)
        case channelAdminLogEventActionExportedInviteDelete(invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionExportedInviteEdit(prevInvite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite)
        case channelAdminLogEventActionExportedInviteRevoke(invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionParticipantInvite(participant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantJoinByInvite(flags: Int32, invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionParticipantJoinByRequest(invite: Api.ExportedChatInvite, approvedBy: Int64)
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantMute(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionParticipantSubExtend(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleBan(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantUnmute(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionParticipantVolume(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionPinTopic(flags: Int32, prevTopic: Api.ForumTopic?, newTopic: Api.ForumTopic?)
        case channelAdminLogEventActionSendMessage(message: Api.Message)
        case channelAdminLogEventActionStartGroupCall(call: Api.InputGroupCall)
        case channelAdminLogEventActionStopPoll(message: Api.Message)
        case channelAdminLogEventActionToggleAntiSpam(newValue: Api.Bool)
        case channelAdminLogEventActionToggleAutotranslation(newValue: Api.Bool)
        case channelAdminLogEventActionToggleForum(newValue: Api.Bool)
        case channelAdminLogEventActionToggleGroupCallSetting(joinMuted: Api.Bool)
        case channelAdminLogEventActionToggleInvites(newValue: Api.Bool)
        case channelAdminLogEventActionToggleNoForwards(newValue: Api.Bool)
        case channelAdminLogEventActionTogglePreHistoryHidden(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSignatureProfiles(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSignatures(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSlowMode(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionUpdatePinned(message: Api.Message)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEventActionChangeAbout(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1427671598)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeAvailableReactions(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-1102180616)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeEmojiStatus(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1051328177)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeEmojiStickerSet(let prevStickerset, let newStickerset):
                    if boxed {
                        buffer.appendInt32(1188577451)
                    }
                    prevStickerset.serialize(buffer, true)
                    newStickerset.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeHistoryTTL(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1855199800)
                    }
                    serializeInt32(prevValue, buffer: buffer, boxed: false)
                    serializeInt32(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeLinkedChat(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(84703944)
                    }
                    serializeInt64(prevValue, buffer: buffer, boxed: false)
                    serializeInt64(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeLocation(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(241923758)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangePeerColor(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1469507456)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangePhoto(let prevPhoto, let newPhoto):
                    if boxed {
                        buffer.appendInt32(1129042607)
                    }
                    prevPhoto.serialize(buffer, true)
                    newPhoto.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeProfilePeerColor(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1581742885)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeStickerSet(let prevStickerset, let newStickerset):
                    if boxed {
                        buffer.appendInt32(-1312568665)
                    }
                    prevStickerset.serialize(buffer, true)
                    newStickerset.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeTitle(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-421545947)
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
                case .channelAdminLogEventActionChangeUsernames(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-263212119)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prevValue.count))
                    for item in prevValue {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newValue.count))
                    for item in newValue {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .channelAdminLogEventActionChangeWallpaper(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(834362706)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionCreateTopic(let topic):
                    if boxed {
                        buffer.appendInt32(1483767080)
                    }
                    topic.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDefaultBannedRights(let prevBannedRights, let newBannedRights):
                    if boxed {
                        buffer.appendInt32(771095562)
                    }
                    prevBannedRights.serialize(buffer, true)
                    newBannedRights.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDeleteMessage(let message):
                    if boxed {
                        buffer.appendInt32(1121994683)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDeleteTopic(let topic):
                    if boxed {
                        buffer.appendInt32(-1374254839)
                    }
                    topic.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDiscardGroupCall(let call):
                    if boxed {
                        buffer.appendInt32(-610299584)
                    }
                    call.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionEditMessage(let prevMessage, let newMessage):
                    if boxed {
                        buffer.appendInt32(1889215493)
                    }
                    prevMessage.serialize(buffer, true)
                    newMessage.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionEditTopic(let prevTopic, let newTopic):
                    if boxed {
                        buffer.appendInt32(-261103096)
                    }
                    prevTopic.serialize(buffer, true)
                    newTopic.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionExportedInviteDelete(let invite):
                    if boxed {
                        buffer.appendInt32(1515256996)
                    }
                    invite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionExportedInviteEdit(let prevInvite, let newInvite):
                    if boxed {
                        buffer.appendInt32(-384910503)
                    }
                    prevInvite.serialize(buffer, true)
                    newInvite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionExportedInviteRevoke(let invite):
                    if boxed {
                        buffer.appendInt32(1091179342)
                    }
                    invite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantInvite(let participant):
                    if boxed {
                        buffer.appendInt32(-484690728)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantJoin:
                    if boxed {
                        buffer.appendInt32(405815507)
                    }
                    
                    break
                case .channelAdminLogEventActionParticipantJoinByInvite(let flags, let invite):
                    if boxed {
                        buffer.appendInt32(-23084712)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    invite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantJoinByRequest(let invite, let approvedBy):
                    if boxed {
                        buffer.appendInt32(-1347021750)
                    }
                    invite.serialize(buffer, true)
                    serializeInt64(approvedBy, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionParticipantLeave:
                    if boxed {
                        buffer.appendInt32(-124291086)
                    }
                    
                    break
                case .channelAdminLogEventActionParticipantMute(let participant):
                    if boxed {
                        buffer.appendInt32(-115071790)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantSubExtend(let prevParticipant, let newParticipant):
                    if boxed {
                        buffer.appendInt32(1684286899)
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
                case .channelAdminLogEventActionParticipantToggleBan(let prevParticipant, let newParticipant):
                    if boxed {
                        buffer.appendInt32(-422036098)
                    }
                    prevParticipant.serialize(buffer, true)
                    newParticipant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantUnmute(let participant):
                    if boxed {
                        buffer.appendInt32(-431740480)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantVolume(let participant):
                    if boxed {
                        buffer.appendInt32(1048537159)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionPinTopic(let flags, let prevTopic, let newTopic):
                    if boxed {
                        buffer.appendInt32(1569535291)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {prevTopic!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {newTopic!.serialize(buffer, true)}
                    break
                case .channelAdminLogEventActionSendMessage(let message):
                    if boxed {
                        buffer.appendInt32(663693416)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionStartGroupCall(let call):
                    if boxed {
                        buffer.appendInt32(589338437)
                    }
                    call.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionStopPoll(let message):
                    if boxed {
                        buffer.appendInt32(-1895328189)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleAntiSpam(let newValue):
                    if boxed {
                        buffer.appendInt32(1693675004)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleAutotranslation(let newValue):
                    if boxed {
                        buffer.appendInt32(-988285058)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleForum(let newValue):
                    if boxed {
                        buffer.appendInt32(46949251)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleGroupCallSetting(let joinMuted):
                    if boxed {
                        buffer.appendInt32(1456906823)
                    }
                    joinMuted.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleInvites(let newValue):
                    if boxed {
                        buffer.appendInt32(460916654)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleNoForwards(let newValue):
                    if boxed {
                        buffer.appendInt32(-886388890)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionTogglePreHistoryHidden(let newValue):
                    if boxed {
                        buffer.appendInt32(1599903217)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSignatureProfiles(let newValue):
                    if boxed {
                        buffer.appendInt32(1621597305)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSignatures(let newValue):
                    if boxed {
                        buffer.appendInt32(648939889)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSlowMode(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1401984889)
                    }
                    serializeInt32(prevValue, buffer: buffer, boxed: false)
                    serializeInt32(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionUpdatePinned(let message):
                    if boxed {
                        buffer.appendInt32(-370660328)
                    }
                    message.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEventActionChangeAbout(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeAbout", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeAvailableReactions(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeAvailableReactions", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeEmojiStatus(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeEmojiStatus", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeEmojiStickerSet(let prevStickerset, let newStickerset):
                return ("channelAdminLogEventActionChangeEmojiStickerSet", [("prevStickerset", prevStickerset as Any), ("newStickerset", newStickerset as Any)])
                case .channelAdminLogEventActionChangeHistoryTTL(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeHistoryTTL", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeLinkedChat(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeLinkedChat", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeLocation(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeLocation", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangePeerColor(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangePeerColor", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangePhoto(let prevPhoto, let newPhoto):
                return ("channelAdminLogEventActionChangePhoto", [("prevPhoto", prevPhoto as Any), ("newPhoto", newPhoto as Any)])
                case .channelAdminLogEventActionChangeProfilePeerColor(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeProfilePeerColor", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeStickerSet(let prevStickerset, let newStickerset):
                return ("channelAdminLogEventActionChangeStickerSet", [("prevStickerset", prevStickerset as Any), ("newStickerset", newStickerset as Any)])
                case .channelAdminLogEventActionChangeTitle(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeTitle", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeUsername(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeUsername", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeUsernames(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeUsernames", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeWallpaper(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeWallpaper", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionCreateTopic(let topic):
                return ("channelAdminLogEventActionCreateTopic", [("topic", topic as Any)])
                case .channelAdminLogEventActionDefaultBannedRights(let prevBannedRights, let newBannedRights):
                return ("channelAdminLogEventActionDefaultBannedRights", [("prevBannedRights", prevBannedRights as Any), ("newBannedRights", newBannedRights as Any)])
                case .channelAdminLogEventActionDeleteMessage(let message):
                return ("channelAdminLogEventActionDeleteMessage", [("message", message as Any)])
                case .channelAdminLogEventActionDeleteTopic(let topic):
                return ("channelAdminLogEventActionDeleteTopic", [("topic", topic as Any)])
                case .channelAdminLogEventActionDiscardGroupCall(let call):
                return ("channelAdminLogEventActionDiscardGroupCall", [("call", call as Any)])
                case .channelAdminLogEventActionEditMessage(let prevMessage, let newMessage):
                return ("channelAdminLogEventActionEditMessage", [("prevMessage", prevMessage as Any), ("newMessage", newMessage as Any)])
                case .channelAdminLogEventActionEditTopic(let prevTopic, let newTopic):
                return ("channelAdminLogEventActionEditTopic", [("prevTopic", prevTopic as Any), ("newTopic", newTopic as Any)])
                case .channelAdminLogEventActionExportedInviteDelete(let invite):
                return ("channelAdminLogEventActionExportedInviteDelete", [("invite", invite as Any)])
                case .channelAdminLogEventActionExportedInviteEdit(let prevInvite, let newInvite):
                return ("channelAdminLogEventActionExportedInviteEdit", [("prevInvite", prevInvite as Any), ("newInvite", newInvite as Any)])
                case .channelAdminLogEventActionExportedInviteRevoke(let invite):
                return ("channelAdminLogEventActionExportedInviteRevoke", [("invite", invite as Any)])
                case .channelAdminLogEventActionParticipantInvite(let participant):
                return ("channelAdminLogEventActionParticipantInvite", [("participant", participant as Any)])
                case .channelAdminLogEventActionParticipantJoin:
                return ("channelAdminLogEventActionParticipantJoin", [])
                case .channelAdminLogEventActionParticipantJoinByInvite(let flags, let invite):
                return ("channelAdminLogEventActionParticipantJoinByInvite", [("flags", flags as Any), ("invite", invite as Any)])
                case .channelAdminLogEventActionParticipantJoinByRequest(let invite, let approvedBy):
                return ("channelAdminLogEventActionParticipantJoinByRequest", [("invite", invite as Any), ("approvedBy", approvedBy as Any)])
                case .channelAdminLogEventActionParticipantLeave:
                return ("channelAdminLogEventActionParticipantLeave", [])
                case .channelAdminLogEventActionParticipantMute(let participant):
                return ("channelAdminLogEventActionParticipantMute", [("participant", participant as Any)])
                case .channelAdminLogEventActionParticipantSubExtend(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantSubExtend", [("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any)])
                case .channelAdminLogEventActionParticipantToggleAdmin(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantToggleAdmin", [("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any)])
                case .channelAdminLogEventActionParticipantToggleBan(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantToggleBan", [("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any)])
                case .channelAdminLogEventActionParticipantUnmute(let participant):
                return ("channelAdminLogEventActionParticipantUnmute", [("participant", participant as Any)])
                case .channelAdminLogEventActionParticipantVolume(let participant):
                return ("channelAdminLogEventActionParticipantVolume", [("participant", participant as Any)])
                case .channelAdminLogEventActionPinTopic(let flags, let prevTopic, let newTopic):
                return ("channelAdminLogEventActionPinTopic", [("flags", flags as Any), ("prevTopic", prevTopic as Any), ("newTopic", newTopic as Any)])
                case .channelAdminLogEventActionSendMessage(let message):
                return ("channelAdminLogEventActionSendMessage", [("message", message as Any)])
                case .channelAdminLogEventActionStartGroupCall(let call):
                return ("channelAdminLogEventActionStartGroupCall", [("call", call as Any)])
                case .channelAdminLogEventActionStopPoll(let message):
                return ("channelAdminLogEventActionStopPoll", [("message", message as Any)])
                case .channelAdminLogEventActionToggleAntiSpam(let newValue):
                return ("channelAdminLogEventActionToggleAntiSpam", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleAutotranslation(let newValue):
                return ("channelAdminLogEventActionToggleAutotranslation", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleForum(let newValue):
                return ("channelAdminLogEventActionToggleForum", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleGroupCallSetting(let joinMuted):
                return ("channelAdminLogEventActionToggleGroupCallSetting", [("joinMuted", joinMuted as Any)])
                case .channelAdminLogEventActionToggleInvites(let newValue):
                return ("channelAdminLogEventActionToggleInvites", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleNoForwards(let newValue):
                return ("channelAdminLogEventActionToggleNoForwards", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionTogglePreHistoryHidden(let newValue):
                return ("channelAdminLogEventActionTogglePreHistoryHidden", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleSignatureProfiles(let newValue):
                return ("channelAdminLogEventActionToggleSignatureProfiles", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleSignatures(let newValue):
                return ("channelAdminLogEventActionToggleSignatures", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleSlowMode(let prevValue, let newValue):
                return ("channelAdminLogEventActionToggleSlowMode", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionUpdatePinned(let message):
                return ("channelAdminLogEventActionUpdatePinned", [("message", message as Any)])
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
        public static func parse_channelAdminLogEventActionChangeAvailableReactions(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChatReactions?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatReactions
            }
            var _2: Api.ChatReactions?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatReactions
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeAvailableReactions(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeEmojiStatus(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.EmojiStatus?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
            var _2: Api.EmojiStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeEmojiStatus(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeEmojiStickerSet(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeEmojiStickerSet(prevStickerset: _1!, newStickerset: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeHistoryTTL(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeHistoryTTL(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeLinkedChat(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
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
        public static func parse_channelAdminLogEventActionChangePeerColor(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.PeerColor?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            var _2: Api.PeerColor?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangePeerColor(prevValue: _1!, newValue: _2!)
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
        public static func parse_channelAdminLogEventActionChangeProfilePeerColor(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.PeerColor?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            var _2: Api.PeerColor?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeProfilePeerColor(prevValue: _1!, newValue: _2!)
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
        public static func parse_channelAdminLogEventActionChangeUsernames(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: [String]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeUsernames(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeWallpaper(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.WallPaper?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            var _2: Api.WallPaper?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeWallpaper(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionCreateTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionCreateTopic(topic: _1!)
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
        public static func parse_channelAdminLogEventActionDeleteTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDeleteTopic(topic: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDiscardGroupCall(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDiscardGroupCall(call: _1!)
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
        public static func parse_channelAdminLogEventActionEditTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            var _2: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionEditTopic(prevTopic: _1!, newTopic: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionExportedInviteDelete(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteDelete(invite: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionExportedInviteEdit(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteEdit(prevInvite: _1!, newInvite: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionExportedInviteRevoke(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteRevoke(invite: _1!)
            }
            else {
                return nil
            }
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
        public static func parse_channelAdminLogEventActionParticipantJoin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoin
        }
        public static func parse_channelAdminLogEventActionParticipantJoinByInvite(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoinByInvite(flags: _1!, invite: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantJoinByRequest(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoinByRequest(invite: _1!, approvedBy: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantLeave(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantLeave
        }
        public static func parse_channelAdminLogEventActionParticipantMute(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.GroupCallParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantMute(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantSubExtend(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantSubExtend(prevParticipant: _1!, newParticipant: _2!)
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
        public static func parse_channelAdminLogEventActionParticipantUnmute(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.GroupCallParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantUnmute(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantVolume(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.GroupCallParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantVolume(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionPinTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ForumTopic?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            } }
            var _3: Api.ForumTopic?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionPinTopic(flags: _1!, prevTopic: _2, newTopic: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionSendMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionSendMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionStartGroupCall(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionStartGroupCall(call: _1!)
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
        public static func parse_channelAdminLogEventActionToggleAntiSpam(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleAntiSpam(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleAutotranslation(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleAutotranslation(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleForum(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleForum(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleGroupCallSetting(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleGroupCallSetting(joinMuted: _1!)
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
        public static func parse_channelAdminLogEventActionToggleNoForwards(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleNoForwards(newValue: _1!)
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
        public static func parse_channelAdminLogEventActionToggleSignatureProfiles(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSignatureProfiles(newValue: _1!)
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
    
    }
}
