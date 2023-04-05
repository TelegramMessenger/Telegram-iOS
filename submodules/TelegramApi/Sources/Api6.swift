public extension Api {
    enum ExportedMessageLink: TypeConstructorDescription {
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
                return ("exportedMessageLink", [("link", link as Any), ("html", html as Any)])
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
}
public extension Api {
    enum FileHash: TypeConstructorDescription {
        case fileHash(offset: Int64, limit: Int32, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileHash(let offset, let limit, let hash):
                    if boxed {
                        buffer.appendInt32(-207944868)
                    }
                    serializeInt64(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileHash(let offset, let limit, let hash):
                return ("fileHash", [("offset", offset as Any), ("limit", limit as Any), ("hash", hash as Any)])
    }
    }
    
        public static func parse_fileHash(_ reader: BufferReader) -> FileHash? {
            var _1: Int64?
            _1 = reader.readInt64()
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
}
public extension Api {
    enum Folder: TypeConstructorDescription {
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
                return ("folder", [("flags", flags as Any), ("id", id as Any), ("title", title as Any), ("photo", photo as Any)])
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
}
public extension Api {
    enum FolderPeer: TypeConstructorDescription {
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
                return ("folderPeer", [("peer", peer as Any), ("folderId", folderId as Any)])
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
}
public extension Api {
    enum ForumTopic: TypeConstructorDescription {
        case forumTopic(flags: Int32, id: Int32, date: Int32, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?)
        case forumTopicDeleted(id: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .forumTopic(let flags, let id, let date, let title, let iconColor, let iconEmojiId, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let fromId, let notifySettings, let draft):
                    if boxed {
                        buffer.appendInt32(1903173033)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt32(iconColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadMentionsCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadReactionsCount, buffer: buffer, boxed: false)
                    fromId.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 4) != 0 {draft!.serialize(buffer, true)}
                    break
                case .forumTopicDeleted(let id):
                    if boxed {
                        buffer.appendInt32(37687451)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .forumTopic(let flags, let id, let date, let title, let iconColor, let iconEmojiId, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let fromId, let notifySettings, let draft):
                return ("forumTopic", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("title", title as Any), ("iconColor", iconColor as Any), ("iconEmojiId", iconEmojiId as Any), ("topMessage", topMessage as Any), ("readInboxMaxId", readInboxMaxId as Any), ("readOutboxMaxId", readOutboxMaxId as Any), ("unreadCount", unreadCount as Any), ("unreadMentionsCount", unreadMentionsCount as Any), ("unreadReactionsCount", unreadReactionsCount as Any), ("fromId", fromId as Any), ("notifySettings", notifySettings as Any), ("draft", draft as Any)])
                case .forumTopicDeleted(let id):
                return ("forumTopicDeleted", [("id", id as Any)])
    }
    }
    
        public static func parse_forumTopic(_ reader: BufferReader) -> ForumTopic? {
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
            var _6: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt64() }
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
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Api.Peer?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _14: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _15: Api.DraftMessage?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 4) == 0) || _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.ForumTopic.forumTopic(flags: _1!, id: _2!, date: _3!, title: _4!, iconColor: _5!, iconEmojiId: _6, topMessage: _7!, readInboxMaxId: _8!, readOutboxMaxId: _9!, unreadCount: _10!, unreadMentionsCount: _11!, unreadReactionsCount: _12!, fromId: _13!, notifySettings: _14!, draft: _15)
            }
            else {
                return nil
            }
        }
        public static func parse_forumTopicDeleted(_ reader: BufferReader) -> ForumTopic? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ForumTopic.forumTopicDeleted(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Game: TypeConstructorDescription {
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
                return ("game", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("shortName", shortName as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("document", document as Any)])
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
}
public extension Api {
    enum GeoPoint: TypeConstructorDescription {
        case geoPoint(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?)
        case geoPointEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .geoPoint(let flags, let long, let lat, let accessHash, let accuracyRadius):
                    if boxed {
                        buffer.appendInt32(-1297942941)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeDouble(long, buffer: buffer, boxed: false)
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(accuracyRadius!, buffer: buffer, boxed: false)}
                    break
                case .geoPointEmpty:
                    if boxed {
                        buffer.appendInt32(286776671)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .geoPoint(let flags, let long, let lat, let accessHash, let accuracyRadius):
                return ("geoPoint", [("flags", flags as Any), ("long", long as Any), ("lat", lat as Any), ("accessHash", accessHash as Any), ("accuracyRadius", accuracyRadius as Any)])
                case .geoPointEmpty:
                return ("geoPointEmpty", [])
    }
    }
    
        public static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPoint.geoPoint(flags: _1!, long: _2!, lat: _3!, accessHash: _4!, accuracyRadius: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            return Api.GeoPoint.geoPointEmpty
        }
    
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription {
        case globalPrivacySettings(flags: Int32, archiveAndMuteNewNoncontactPeers: Api.Bool?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .globalPrivacySettings(let flags, let archiveAndMuteNewNoncontactPeers):
                    if boxed {
                        buffer.appendInt32(-1096616924)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {archiveAndMuteNewNoncontactPeers!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .globalPrivacySettings(let flags, let archiveAndMuteNewNoncontactPeers):
                return ("globalPrivacySettings", [("flags", flags as Any), ("archiveAndMuteNewNoncontactPeers", archiveAndMuteNewNoncontactPeers as Any)])
    }
    }
    
        public static func parse_globalPrivacySettings(_ reader: BufferReader) -> GlobalPrivacySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.GlobalPrivacySettings.globalPrivacySettings(flags: _1!, archiveAndMuteNewNoncontactPeers: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32)
        case groupCallDiscarded(id: Int64, accessHash: Int64, duration: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCall(let flags, let id, let accessHash, let participantsCount, let title, let streamDcId, let recordStartDate, let scheduleDate, let unmutedVideoCount, let unmutedVideoLimit, let version):
                    if boxed {
                        buffer.appendInt32(-711498484)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(streamDcId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(recordStartDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(unmutedVideoCount!, buffer: buffer, boxed: false)}
                    serializeInt32(unmutedVideoLimit, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .groupCallDiscarded(let id, let accessHash, let duration):
                    if boxed {
                        buffer.appendInt32(2004925620)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCall(let flags, let id, let accessHash, let participantsCount, let title, let streamDcId, let recordStartDate, let scheduleDate, let unmutedVideoCount, let unmutedVideoLimit, let version):
                return ("groupCall", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("participantsCount", participantsCount as Any), ("title", title as Any), ("streamDcId", streamDcId as Any), ("recordStartDate", recordStartDate as Any), ("scheduleDate", scheduleDate as Any), ("unmutedVideoCount", unmutedVideoCount as Any), ("unmutedVideoLimit", unmutedVideoLimit as Any), ("version", version as Any)])
                case .groupCallDiscarded(let id, let accessHash, let duration):
                return ("groupCallDiscarded", [("id", id as Any), ("accessHash", accessHash as Any), ("duration", duration as Any)])
    }
    }
    
        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_7 = reader.readInt32() }
            var _8: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 10) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.GroupCall.groupCall(flags: _1!, id: _2!, accessHash: _3!, participantsCount: _4!, title: _5, streamDcId: _6, recordStartDate: _7, scheduleDate: _8, unmutedVideoCount: _9, unmutedVideoLimit: _10!, version: _11!)
            }
            else {
                return nil
            }
        }
        public static func parse_groupCallDiscarded(_ reader: BufferReader) -> GroupCall? {
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
                return Api.GroupCall.groupCallDiscarded(id: _1!, accessHash: _2!, duration: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallParticipant: TypeConstructorDescription {
        case groupCallParticipant(flags: Int32, peer: Api.Peer, date: Int32, activeDate: Int32?, source: Int32, volume: Int32?, about: String?, raiseHandRating: Int64?, video: Api.GroupCallParticipantVideo?, presentation: Api.GroupCallParticipantVideo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipant(let flags, let peer, let date, let activeDate, let source, let volume, let about, let raiseHandRating, let video, let presentation):
                    if boxed {
                        buffer.appendInt32(-341428482)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(activeDate!, buffer: buffer, boxed: false)}
                    serializeInt32(source, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(volume!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt64(raiseHandRating!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {presentation!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipant(let flags, let peer, let date, let activeDate, let source, let volume, let about, let raiseHandRating, let video, let presentation):
                return ("groupCallParticipant", [("flags", flags as Any), ("peer", peer as Any), ("date", date as Any), ("activeDate", activeDate as Any), ("source", source as Any), ("volume", volume as Any), ("about", about as Any), ("raiseHandRating", raiseHandRating as Any), ("video", video as Any), ("presentation", presentation as Any)])
    }
    }
    
        public static func parse_groupCallParticipant(_ reader: BufferReader) -> GroupCallParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 11) != 0 {_7 = parseString(reader) }
            var _8: Int64?
            if Int(_1!) & Int(1 << 13) != 0 {_8 = reader.readInt64() }
            var _9: Api.GroupCallParticipantVideo?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
            } }
            var _10: Api.GroupCallParticipantVideo?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 7) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 13) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.GroupCallParticipant.groupCallParticipant(flags: _1!, peer: _2!, date: _3!, activeDate: _4, source: _5!, volume: _6, about: _7, raiseHandRating: _8, video: _9, presentation: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallParticipantVideo: TypeConstructorDescription {
        case groupCallParticipantVideo(flags: Int32, endpoint: String, sourceGroups: [Api.GroupCallParticipantVideoSourceGroup], audioSource: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipantVideo(let flags, let endpoint, let sourceGroups, let audioSource):
                    if boxed {
                        buffer.appendInt32(1735736008)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(endpoint, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sourceGroups.count))
                    for item in sourceGroups {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(audioSource!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipantVideo(let flags, let endpoint, let sourceGroups, let audioSource):
                return ("groupCallParticipantVideo", [("flags", flags as Any), ("endpoint", endpoint as Any), ("sourceGroups", sourceGroups as Any), ("audioSource", audioSource as Any)])
    }
    }
    
        public static func parse_groupCallParticipantVideo(_ reader: BufferReader) -> GroupCallParticipantVideo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.GroupCallParticipantVideoSourceGroup]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipantVideoSourceGroup.self)
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.GroupCallParticipantVideo.groupCallParticipantVideo(flags: _1!, endpoint: _2!, sourceGroups: _3!, audioSource: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription {
        case groupCallParticipantVideoSourceGroup(semantics: String, sources: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipantVideoSourceGroup(let semantics, let sources):
                    if boxed {
                        buffer.appendInt32(-592373577)
                    }
                    serializeString(semantics, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sources.count))
                    for item in sources {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipantVideoSourceGroup(let semantics, let sources):
                return ("groupCallParticipantVideoSourceGroup", [("semantics", semantics as Any), ("sources", sources as Any)])
    }
    }
    
        public static func parse_groupCallParticipantVideoSourceGroup(_ reader: BufferReader) -> GroupCallParticipantVideoSourceGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.GroupCallParticipantVideoSourceGroup.groupCallParticipantVideoSourceGroup(semantics: _1!, sources: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription {
        case groupCallStreamChannel(channel: Int32, scale: Int32, lastTimestampMs: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamChannel(let channel, let scale, let lastTimestampMs):
                    if boxed {
                        buffer.appendInt32(-2132064081)
                    }
                    serializeInt32(channel, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    serializeInt64(lastTimestampMs, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamChannel(let channel, let scale, let lastTimestampMs):
                return ("groupCallStreamChannel", [("channel", channel as Any), ("scale", scale as Any), ("lastTimestampMs", lastTimestampMs as Any)])
    }
    }
    
        public static func parse_groupCallStreamChannel(_ reader: BufferReader) -> GroupCallStreamChannel? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCallStreamChannel.groupCallStreamChannel(channel: _1!, scale: _2!, lastTimestampMs: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription {
        case highScore(pos: Int32, userId: Int64, score: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .highScore(let pos, let userId, let score):
                    if boxed {
                        buffer.appendInt32(1940093419)
                    }
                    serializeInt32(pos, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .highScore(let pos, let userId, let score):
                return ("highScore", [("pos", pos as Any), ("userId", userId as Any), ("score", score as Any)])
    }
    }
    
        public static func parse_highScore(_ reader: BufferReader) -> HighScore? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
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
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription {
        case importedContact(userId: Int64, clientId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .importedContact(let userId, let clientId):
                    if boxed {
                        buffer.appendInt32(-1052885936)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .importedContact(let userId, let clientId):
                return ("importedContact", [("userId", userId as Any), ("clientId", clientId as Any)])
    }
    }
    
        public static func parse_importedContact(_ reader: BufferReader) -> ImportedContact? {
            var _1: Int64?
            _1 = reader.readInt64()
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
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription {
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
                return ("inlineBotSwitchPM", [("text", text as Any), ("startParam", startParam as Any)])
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
}
public extension Api {
    enum InlineBotWebView: TypeConstructorDescription {
        case inlineBotWebView(text: String, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineBotWebView(let text, let url):
                    if boxed {
                        buffer.appendInt32(-1250781739)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineBotWebView(let text, let url):
                return ("inlineBotWebView", [("text", text as Any), ("url", url as Any)])
    }
    }
    
        public static func parse_inlineBotWebView(_ reader: BufferReader) -> InlineBotWebView? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineBotWebView.inlineBotWebView(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InlineQueryPeerType: TypeConstructorDescription {
        case inlineQueryPeerTypeBotPM
        case inlineQueryPeerTypeBroadcast
        case inlineQueryPeerTypeChat
        case inlineQueryPeerTypeMegagroup
        case inlineQueryPeerTypePM
        case inlineQueryPeerTypeSameBotPM
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineQueryPeerTypeBotPM:
                    if boxed {
                        buffer.appendInt32(238759180)
                    }
                    
                    break
                case .inlineQueryPeerTypeBroadcast:
                    if boxed {
                        buffer.appendInt32(1664413338)
                    }
                    
                    break
                case .inlineQueryPeerTypeChat:
                    if boxed {
                        buffer.appendInt32(-681130742)
                    }
                    
                    break
                case .inlineQueryPeerTypeMegagroup:
                    if boxed {
                        buffer.appendInt32(1589952067)
                    }
                    
                    break
                case .inlineQueryPeerTypePM:
                    if boxed {
                        buffer.appendInt32(-2093215828)
                    }
                    
                    break
                case .inlineQueryPeerTypeSameBotPM:
                    if boxed {
                        buffer.appendInt32(813821341)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineQueryPeerTypeBotPM:
                return ("inlineQueryPeerTypeBotPM", [])
                case .inlineQueryPeerTypeBroadcast:
                return ("inlineQueryPeerTypeBroadcast", [])
                case .inlineQueryPeerTypeChat:
                return ("inlineQueryPeerTypeChat", [])
                case .inlineQueryPeerTypeMegagroup:
                return ("inlineQueryPeerTypeMegagroup", [])
                case .inlineQueryPeerTypePM:
                return ("inlineQueryPeerTypePM", [])
                case .inlineQueryPeerTypeSameBotPM:
                return ("inlineQueryPeerTypeSameBotPM", [])
    }
    }
    
        public static func parse_inlineQueryPeerTypeBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeBotPM
        }
        public static func parse_inlineQueryPeerTypeBroadcast(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeBroadcast
        }
        public static func parse_inlineQueryPeerTypeChat(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeChat
        }
        public static func parse_inlineQueryPeerTypeMegagroup(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeMegagroup
        }
        public static func parse_inlineQueryPeerTypePM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypePM
        }
        public static func parse_inlineQueryPeerTypeSameBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeSameBotPM
        }
    
    }
}
public extension Api {
    enum InputAppEvent: TypeConstructorDescription {
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
                return ("inputAppEvent", [("time", time as Any), ("type", type as Any), ("peer", peer as Any), ("data", data as Any)])
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
}
public extension Api {
    indirect enum InputBotApp: TypeConstructorDescription {
        case inputBotAppID(id: Int64, accessHash: Int64)
        case inputBotAppShortName(botId: Api.InputUser, shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotAppID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1457472134)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputBotAppShortName(let botId, let shortName):
                    if boxed {
                        buffer.appendInt32(-1869872121)
                    }
                    botId.serialize(buffer, true)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotAppID(let id, let accessHash):
                return ("inputBotAppID", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputBotAppShortName(let botId, let shortName):
                return ("inputBotAppShortName", [("botId", botId as Any), ("shortName", shortName as Any)])
    }
    }
    
        public static func parse_inputBotAppID(_ reader: BufferReader) -> InputBotApp? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputBotApp.inputBotAppID(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotAppShortName(_ reader: BufferReader) -> InputBotApp? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputBotApp.inputBotAppShortName(botId: _1!, shortName: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBotInlineMessage: TypeConstructorDescription {
        case inputBotInlineMessageGame(flags: Int32, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaGeo(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaVenue(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageText(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1768777083)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(heading!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(period!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(proximityNotificationRadius!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-672693723)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    providerData.serialize(buffer, true)
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineMessageGame(let flags, let replyMarkup):
                return ("inputBotInlineMessageGame", [("flags", flags as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageMediaAuto", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                return ("inputBotInlineMessageMediaContact", [("flags", flags as Any), ("phoneNumber", phoneNumber as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("vcard", vcard as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                return ("inputBotInlineMessageMediaGeo", [("flags", flags as Any), ("geoPoint", geoPoint as Any), ("heading", heading as Any), ("period", period as Any), ("proximityNotificationRadius", proximityNotificationRadius as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let replyMarkup):
                return ("inputBotInlineMessageMediaInvoice", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("payload", payload as Any), ("provider", provider as Any), ("providerData", providerData as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaVenue(let flags, let geoPoint, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                return ("inputBotInlineMessageMediaVenue", [("flags", flags as Any), ("geoPoint", geoPoint as Any), ("title", title as Any), ("address", address as Any), ("provider", provider as Any), ("venueId", venueId as Any), ("venueType", venueType as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageText(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageText", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("replyMarkup", replyMarkup as Any)])
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
        public static func parse_inputBotInlineMessageMediaGeo(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = reader.readInt32() }
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaGeo(flags: _1!, geoPoint: _2!, heading: _3, period: _4, proximityNotificationRadius: _5, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaInvoice(_ reader: BufferReader) -> InputBotInlineMessage? {
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
            var _9: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7!, providerData: _8!, replyMarkup: _9)
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
    
    }
}
