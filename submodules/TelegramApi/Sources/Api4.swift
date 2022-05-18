public extension Api {
    enum ChatInviteImporter: TypeConstructorDescription {
        case chatInviteImporter(flags: Int32, userId: Int64, date: Int32, about: String?, approvedBy: Int64?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatInviteImporter(let flags, let userId, let date, let about, let approvedBy):
                    if boxed {
                        buffer.appendInt32(-1940201511)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(approvedBy!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatInviteImporter(let flags, let userId, let date, let about, let approvedBy):
                return ("chatInviteImporter", [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("date", String(describing: date)), ("about", String(describing: about)), ("approvedBy", String(describing: approvedBy))])
    }
    }
    
        public static func parse_chatInviteImporter(_ reader: BufferReader) -> ChatInviteImporter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChatInviteImporter.chatInviteImporter(flags: _1!, userId: _2!, date: _3!, about: _4, approvedBy: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChatOnlines: TypeConstructorDescription {
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
                return ("chatOnlines", [("onlines", String(describing: onlines))])
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
}
public extension Api {
    enum ChatParticipant: TypeConstructorDescription {
        case chatParticipant(userId: Int64, inviterId: Int64, date: Int32)
        case chatParticipantAdmin(userId: Int64, inviterId: Int64, date: Int32)
        case chatParticipantCreator(userId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatParticipant(let userId, let inviterId, let date):
                    if boxed {
                        buffer.appendInt32(-1070776313)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .chatParticipantAdmin(let userId, let inviterId, let date):
                    if boxed {
                        buffer.appendInt32(-1600962725)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .chatParticipantCreator(let userId):
                    if boxed {
                        buffer.appendInt32(-462696732)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatParticipant(let userId, let inviterId, let date):
                return ("chatParticipant", [("userId", String(describing: userId)), ("inviterId", String(describing: inviterId)), ("date", String(describing: date))])
                case .chatParticipantAdmin(let userId, let inviterId, let date):
                return ("chatParticipantAdmin", [("userId", String(describing: userId)), ("inviterId", String(describing: inviterId)), ("date", String(describing: date))])
                case .chatParticipantCreator(let userId):
                return ("chatParticipantCreator", [("userId", String(describing: userId))])
    }
    }
    
        public static func parse_chatParticipant(_ reader: BufferReader) -> ChatParticipant? {
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
                return Api.ChatParticipant.chatParticipant(userId: _1!, inviterId: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantAdmin(_ reader: BufferReader) -> ChatParticipant? {
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
                return Api.ChatParticipant.chatParticipantAdmin(userId: _1!, inviterId: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantCreator(_ reader: BufferReader) -> ChatParticipant? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatParticipant.chatParticipantCreator(userId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChatParticipants: TypeConstructorDescription {
        case chatParticipants(chatId: Int64, participants: [Api.ChatParticipant], version: Int32)
        case chatParticipantsForbidden(flags: Int32, chatId: Int64, selfParticipant: Api.ChatParticipant?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatParticipants(let chatId, let participants, let version):
                    if boxed {
                        buffer.appendInt32(1018991608)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .chatParticipantsForbidden(let flags, let chatId, let selfParticipant):
                    if boxed {
                        buffer.appendInt32(-2023500831)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {selfParticipant!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatParticipants(let chatId, let participants, let version):
                return ("chatParticipants", [("chatId", String(describing: chatId)), ("participants", String(describing: participants)), ("version", String(describing: version))])
                case .chatParticipantsForbidden(let flags, let chatId, let selfParticipant):
                return ("chatParticipantsForbidden", [("flags", String(describing: flags)), ("chatId", String(describing: chatId)), ("selfParticipant", String(describing: selfParticipant))])
    }
    }
    
        public static func parse_chatParticipants(_ reader: BufferReader) -> ChatParticipants? {
            var _1: Int64?
            _1 = reader.readInt64()
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
        public static func parse_chatParticipantsForbidden(_ reader: BufferReader) -> ChatParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
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
    
    }
}
public extension Api {
    enum ChatPhoto: TypeConstructorDescription {
        case chatPhoto(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32)
        case chatPhotoEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatPhoto(let flags, let photoId, let strippedThumb, let dcId):
                    if boxed {
                        buffer.appendInt32(476978193)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(photoId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeBytes(strippedThumb!, buffer: buffer, boxed: false)}
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    break
                case .chatPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(935395612)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatPhoto(let flags, let photoId, let strippedThumb, let dcId):
                return ("chatPhoto", [("flags", String(describing: flags)), ("photoId", String(describing: photoId)), ("strippedThumb", String(describing: strippedThumb)), ("dcId", String(describing: dcId))])
                case .chatPhotoEmpty:
                return ("chatPhotoEmpty", [])
    }
    }
    
        public static func parse_chatPhoto(_ reader: BufferReader) -> ChatPhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseBytes(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChatPhoto.chatPhoto(flags: _1!, photoId: _2!, strippedThumb: _3, dcId: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatPhotoEmpty(_ reader: BufferReader) -> ChatPhoto? {
            return Api.ChatPhoto.chatPhotoEmpty
        }
    
    }
}
public extension Api {
    enum CodeSettings: TypeConstructorDescription {
        case codeSettings(flags: Int32, logoutTokens: [Buffer]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .codeSettings(let flags, let logoutTokens):
                    if boxed {
                        buffer.appendInt32(-1973130814)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(logoutTokens!.count))
                    for item in logoutTokens! {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .codeSettings(let flags, let logoutTokens):
                return ("codeSettings", [("flags", String(describing: flags)), ("logoutTokens", String(describing: logoutTokens))])
    }
    }
    
        public static func parse_codeSettings(_ reader: BufferReader) -> CodeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Buffer]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 6) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.CodeSettings.codeSettings(flags: _1!, logoutTokens: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Config: TypeConstructorDescription {
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
                return ("config", [("flags", String(describing: flags)), ("date", String(describing: date)), ("expires", String(describing: expires)), ("testMode", String(describing: testMode)), ("thisDc", String(describing: thisDc)), ("dcOptions", String(describing: dcOptions)), ("dcTxtDomainName", String(describing: dcTxtDomainName)), ("chatSizeMax", String(describing: chatSizeMax)), ("megagroupSizeMax", String(describing: megagroupSizeMax)), ("forwardedCountMax", String(describing: forwardedCountMax)), ("onlineUpdatePeriodMs", String(describing: onlineUpdatePeriodMs)), ("offlineBlurTimeoutMs", String(describing: offlineBlurTimeoutMs)), ("offlineIdleTimeoutMs", String(describing: offlineIdleTimeoutMs)), ("onlineCloudTimeoutMs", String(describing: onlineCloudTimeoutMs)), ("notifyCloudDelayMs", String(describing: notifyCloudDelayMs)), ("notifyDefaultDelayMs", String(describing: notifyDefaultDelayMs)), ("pushChatPeriodMs", String(describing: pushChatPeriodMs)), ("pushChatLimit", String(describing: pushChatLimit)), ("savedGifsLimit", String(describing: savedGifsLimit)), ("editTimeLimit", String(describing: editTimeLimit)), ("revokeTimeLimit", String(describing: revokeTimeLimit)), ("revokePmTimeLimit", String(describing: revokePmTimeLimit)), ("ratingEDecay", String(describing: ratingEDecay)), ("stickersRecentLimit", String(describing: stickersRecentLimit)), ("stickersFavedLimit", String(describing: stickersFavedLimit)), ("channelsReadMediaPeriod", String(describing: channelsReadMediaPeriod)), ("tmpSessions", String(describing: tmpSessions)), ("pinnedDialogsCountMax", String(describing: pinnedDialogsCountMax)), ("pinnedInfolderCountMax", String(describing: pinnedInfolderCountMax)), ("callReceiveTimeoutMs", String(describing: callReceiveTimeoutMs)), ("callRingTimeoutMs", String(describing: callRingTimeoutMs)), ("callConnectTimeoutMs", String(describing: callConnectTimeoutMs)), ("callPacketTimeoutMs", String(describing: callPacketTimeoutMs)), ("meUrlPrefix", String(describing: meUrlPrefix)), ("autoupdateUrlPrefix", String(describing: autoupdateUrlPrefix)), ("gifSearchUsername", String(describing: gifSearchUsername)), ("venueSearchUsername", String(describing: venueSearchUsername)), ("imgSearchUsername", String(describing: imgSearchUsername)), ("staticMapsProvider", String(describing: staticMapsProvider)), ("captionLengthMax", String(describing: captionLengthMax)), ("messageLengthMax", String(describing: messageLengthMax)), ("webfileDcId", String(describing: webfileDcId)), ("suggestedLangCode", String(describing: suggestedLangCode)), ("langPackVersion", String(describing: langPackVersion)), ("baseLangPackVersion", String(describing: baseLangPackVersion))])
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
}
public extension Api {
    enum Contact: TypeConstructorDescription {
        case contact(userId: Int64, mutual: Api.Bool)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contact(let userId, let mutual):
                    if boxed {
                        buffer.appendInt32(341499403)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    mutual.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contact(let userId, let mutual):
                return ("contact", [("userId", String(describing: userId)), ("mutual", String(describing: mutual))])
    }
    }
    
        public static func parse_contact(_ reader: BufferReader) -> Contact? {
            var _1: Int64?
            _1 = reader.readInt64()
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
}
public extension Api {
    enum ContactStatus: TypeConstructorDescription {
        case contactStatus(userId: Int64, status: Api.UserStatus)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contactStatus(let userId, let status):
                    if boxed {
                        buffer.appendInt32(383348795)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    status.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contactStatus(let userId, let status):
                return ("contactStatus", [("userId", String(describing: userId)), ("status", String(describing: status))])
    }
    }
    
        public static func parse_contactStatus(_ reader: BufferReader) -> ContactStatus? {
            var _1: Int64?
            _1 = reader.readInt64()
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
}
public extension Api {
    enum DataJSON: TypeConstructorDescription {
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
                return ("dataJSON", [("data", String(describing: data))])
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
}
public extension Api {
    enum DcOption: TypeConstructorDescription {
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
                return ("dcOption", [("flags", String(describing: flags)), ("id", String(describing: id)), ("ipAddress", String(describing: ipAddress)), ("port", String(describing: port)), ("secret", String(describing: secret))])
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
}
public extension Api {
    enum Dialog: TypeConstructorDescription {
        case dialog(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, notifySettings: Api.PeerNotifySettings, pts: Int32?, draft: Api.DraftMessage?, folderId: Int32?)
        case dialogFolder(flags: Int32, folder: Api.Folder, peer: Api.Peer, topMessage: Int32, unreadMutedPeersCount: Int32, unreadUnmutedPeersCount: Int32, unreadMutedMessagesCount: Int32, unreadUnmutedMessagesCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialog(let flags, let peer, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let notifySettings, let pts, let draft, let folderId):
                    if boxed {
                        buffer.appendInt32(-1460809483)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadMentionsCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadReactionsCount, buffer: buffer, boxed: false)
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
                case .dialog(let flags, let peer, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let notifySettings, let pts, let draft, let folderId):
                return ("dialog", [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMessage", String(describing: topMessage)), ("readInboxMaxId", String(describing: readInboxMaxId)), ("readOutboxMaxId", String(describing: readOutboxMaxId)), ("unreadCount", String(describing: unreadCount)), ("unreadMentionsCount", String(describing: unreadMentionsCount)), ("unreadReactionsCount", String(describing: unreadReactionsCount)), ("notifySettings", String(describing: notifySettings)), ("pts", String(describing: pts)), ("draft", String(describing: draft)), ("folderId", String(describing: folderId))])
                case .dialogFolder(let flags, let folder, let peer, let topMessage, let unreadMutedPeersCount, let unreadUnmutedPeersCount, let unreadMutedMessagesCount, let unreadUnmutedMessagesCount):
                return ("dialogFolder", [("flags", String(describing: flags)), ("folder", String(describing: folder)), ("peer", String(describing: peer)), ("topMessage", String(describing: topMessage)), ("unreadMutedPeersCount", String(describing: unreadMutedPeersCount)), ("unreadUnmutedPeersCount", String(describing: unreadUnmutedPeersCount)), ("unreadMutedMessagesCount", String(describing: unreadMutedMessagesCount)), ("unreadUnmutedMessagesCount", String(describing: unreadUnmutedMessagesCount))])
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
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_10 = reader.readInt32() }
            var _11: Api.DraftMessage?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            } }
            var _12: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_12 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 0) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 1) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 4) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.Dialog.dialog(flags: _1!, peer: _2!, topMessage: _3!, readInboxMaxId: _4!, readOutboxMaxId: _5!, unreadCount: _6!, unreadMentionsCount: _7!, unreadReactionsCount: _8!, notifySettings: _9!, pts: _10, draft: _11, folderId: _12)
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
}
public extension Api {
    enum DialogFilter: TypeConstructorDescription {
        case dialogFilter(flags: Int32, id: Int32, title: String, emoticon: String?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer], excludePeers: [Api.InputPeer])
        case dialogFilterDefault
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialogFilter(let flags, let id, let title, let emoticon, let pinnedPeers, let includePeers, let excludePeers):
                    if boxed {
                        buffer.appendInt32(1949890536)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 25) != 0 {serializeString(emoticon!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(pinnedPeers.count))
                    for item in pinnedPeers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(includePeers.count))
                    for item in includePeers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(excludePeers.count))
                    for item in excludePeers {
                        item.serialize(buffer, true)
                    }
                    break
                case .dialogFilterDefault:
                    if boxed {
                        buffer.appendInt32(909284270)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dialogFilter(let flags, let id, let title, let emoticon, let pinnedPeers, let includePeers, let excludePeers):
                return ("dialogFilter", [("flags", String(describing: flags)), ("id", String(describing: id)), ("title", String(describing: title)), ("emoticon", String(describing: emoticon)), ("pinnedPeers", String(describing: pinnedPeers)), ("includePeers", String(describing: includePeers)), ("excludePeers", String(describing: excludePeers))])
                case .dialogFilterDefault:
                return ("dialogFilterDefault", [])
    }
    }
    
        public static func parse_dialogFilter(_ reader: BufferReader) -> DialogFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 25) != 0 {_4 = parseString(reader) }
            var _5: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            var _6: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            var _7: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 25) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.DialogFilter.dialogFilter(flags: _1!, id: _2!, title: _3!, emoticon: _4, pinnedPeers: _5!, includePeers: _6!, excludePeers: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_dialogFilterDefault(_ reader: BufferReader) -> DialogFilter? {
            return Api.DialogFilter.dialogFilterDefault
        }
    
    }
}
public extension Api {
    enum DialogFilterSuggested: TypeConstructorDescription {
        case dialogFilterSuggested(filter: Api.DialogFilter, description: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialogFilterSuggested(let filter, let description):
                    if boxed {
                        buffer.appendInt32(2004110666)
                    }
                    filter.serialize(buffer, true)
                    serializeString(description, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dialogFilterSuggested(let filter, let description):
                return ("dialogFilterSuggested", [("filter", String(describing: filter)), ("description", String(describing: description))])
    }
    }
    
        public static func parse_dialogFilterSuggested(_ reader: BufferReader) -> DialogFilterSuggested? {
            var _1: Api.DialogFilter?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DialogFilter
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.DialogFilterSuggested.dialogFilterSuggested(filter: _1!, description: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum DialogPeer: TypeConstructorDescription {
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
                return ("dialogPeer", [("peer", String(describing: peer))])
                case .dialogPeerFolder(let folderId):
                return ("dialogPeerFolder", [("folderId", String(describing: folderId))])
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
}
public extension Api {
    enum Document: TypeConstructorDescription {
        case document(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, mimeType: String, size: Int64, thumbs: [Api.PhotoSize]?, videoThumbs: [Api.VideoSize]?, dcId: Int32, attributes: [Api.DocumentAttribute])
        case documentEmpty(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .document(let flags, let id, let accessHash, let fileReference, let date, let mimeType, let size, let thumbs, let videoThumbs, let dcId, let attributes):
                    if boxed {
                        buffer.appendInt32(-1881881384)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt64(size, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(thumbs!.count))
                    for item in thumbs! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(videoThumbs!.count))
                    for item in videoThumbs! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
                case .documentEmpty(let id):
                    if boxed {
                        buffer.appendInt32(922273905)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .document(let flags, let id, let accessHash, let fileReference, let date, let mimeType, let size, let thumbs, let videoThumbs, let dcId, let attributes):
                return ("document", [("flags", String(describing: flags)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference)), ("date", String(describing: date)), ("mimeType", String(describing: mimeType)), ("size", String(describing: size)), ("thumbs", String(describing: thumbs)), ("videoThumbs", String(describing: videoThumbs)), ("dcId", String(describing: dcId)), ("attributes", String(describing: attributes))])
                case .documentEmpty(let id):
                return ("documentEmpty", [("id", String(describing: id))])
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
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: [Api.PhotoSize]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
            } }
            var _9: [Api.VideoSize]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.VideoSize.self)
            } }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.Document.document(flags: _1!, id: _2!, accessHash: _3!, fileReference: _4!, date: _5!, mimeType: _6!, size: _7!, thumbs: _8, videoThumbs: _9, dcId: _10!, attributes: _11!)
            }
            else {
                return nil
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
    
    }
}
public extension Api {
    enum DocumentAttribute: TypeConstructorDescription {
        case documentAttributeAnimated
        case documentAttributeAudio(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?)
        case documentAttributeFilename(fileName: String)
        case documentAttributeHasStickers
        case documentAttributeImageSize(w: Int32, h: Int32)
        case documentAttributeSticker(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?)
        case documentAttributeVideo(flags: Int32, duration: Int32, w: Int32, h: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .documentAttributeAnimated:
                    if boxed {
                        buffer.appendInt32(297109817)
                    }
                    
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
                case .documentAttributeImageSize(let w, let h):
                    if boxed {
                        buffer.appendInt32(1815593308)
                    }
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .documentAttributeAnimated:
                return ("documentAttributeAnimated", [])
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                return ("documentAttributeAudio", [("flags", String(describing: flags)), ("duration", String(describing: duration)), ("title", String(describing: title)), ("performer", String(describing: performer)), ("waveform", String(describing: waveform))])
                case .documentAttributeFilename(let fileName):
                return ("documentAttributeFilename", [("fileName", String(describing: fileName))])
                case .documentAttributeHasStickers:
                return ("documentAttributeHasStickers", [])
                case .documentAttributeImageSize(let w, let h):
                return ("documentAttributeImageSize", [("w", String(describing: w)), ("h", String(describing: h))])
                case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                return ("documentAttributeSticker", [("flags", String(describing: flags)), ("alt", String(describing: alt)), ("stickerset", String(describing: stickerset)), ("maskCoords", String(describing: maskCoords))])
                case .documentAttributeVideo(let flags, let duration, let w, let h):
                return ("documentAttributeVideo", [("flags", String(describing: flags)), ("duration", String(describing: duration)), ("w", String(describing: w)), ("h", String(describing: h))])
    }
    }
    
        public static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeAnimated
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
    
    }
}
public extension Api {
    enum DraftMessage: TypeConstructorDescription {
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
                return ("draftMessage", [("flags", String(describing: flags)), ("replyToMsgId", String(describing: replyToMsgId)), ("message", String(describing: message)), ("entities", String(describing: entities)), ("date", String(describing: date))])
                case .draftMessageEmpty(let flags, let date):
                return ("draftMessageEmpty", [("flags", String(describing: flags)), ("date", String(describing: date))])
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
}
