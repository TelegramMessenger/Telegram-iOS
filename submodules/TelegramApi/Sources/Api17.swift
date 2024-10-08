public extension Api {
    enum NotificationSound: TypeConstructorDescription {
        case notificationSoundDefault
        case notificationSoundLocal(title: String, data: String)
        case notificationSoundNone
        case notificationSoundRingtone(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .notificationSoundDefault:
                    if boxed {
                        buffer.appendInt32(-1746354498)
                    }
                    
                    break
                case .notificationSoundLocal(let title, let data):
                    if boxed {
                        buffer.appendInt32(-2096391452)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(data, buffer: buffer, boxed: false)
                    break
                case .notificationSoundNone:
                    if boxed {
                        buffer.appendInt32(1863070943)
                    }
                    
                    break
                case .notificationSoundRingtone(let id):
                    if boxed {
                        buffer.appendInt32(-9666487)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .notificationSoundDefault:
                return ("notificationSoundDefault", [])
                case .notificationSoundLocal(let title, let data):
                return ("notificationSoundLocal", [("title", title as Any), ("data", data as Any)])
                case .notificationSoundNone:
                return ("notificationSoundNone", [])
                case .notificationSoundRingtone(let id):
                return ("notificationSoundRingtone", [("id", id as Any)])
    }
    }
    
        public static func parse_notificationSoundDefault(_ reader: BufferReader) -> NotificationSound? {
            return Api.NotificationSound.notificationSoundDefault
        }
        public static func parse_notificationSoundLocal(_ reader: BufferReader) -> NotificationSound? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.NotificationSound.notificationSoundLocal(title: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_notificationSoundNone(_ reader: BufferReader) -> NotificationSound? {
            return Api.NotificationSound.notificationSoundNone
        }
        public static func parse_notificationSoundRingtone(_ reader: BufferReader) -> NotificationSound? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotificationSound.notificationSoundRingtone(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum NotifyPeer: TypeConstructorDescription {
        case notifyBroadcasts
        case notifyChats
        case notifyForumTopic(peer: Api.Peer, topMsgId: Int32)
        case notifyPeer(peer: Api.Peer)
        case notifyUsers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .notifyBroadcasts:
                    if boxed {
                        buffer.appendInt32(-703403793)
                    }
                    
                    break
                case .notifyChats:
                    if boxed {
                        buffer.appendInt32(-1073230141)
                    }
                    
                    break
                case .notifyForumTopic(let peer, let topMsgId):
                    if boxed {
                        buffer.appendInt32(577659656)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    break
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .notifyBroadcasts:
                return ("notifyBroadcasts", [])
                case .notifyChats:
                return ("notifyChats", [])
                case .notifyForumTopic(let peer, let topMsgId):
                return ("notifyForumTopic", [("peer", peer as Any), ("topMsgId", topMsgId as Any)])
                case .notifyPeer(let peer):
                return ("notifyPeer", [("peer", peer as Any)])
                case .notifyUsers:
                return ("notifyUsers", [])
    }
    }
    
        public static func parse_notifyBroadcasts(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyBroadcasts
        }
        public static func parse_notifyChats(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyChats
        }
        public static func parse_notifyForumTopic(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.NotifyPeer.notifyForumTopic(peer: _1!, topMsgId: _2!)
            }
            else {
                return nil
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
    
    }
}
public extension Api {
    enum OutboxReadDate: TypeConstructorDescription {
        case outboxReadDate(date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .outboxReadDate(let date):
                    if boxed {
                        buffer.appendInt32(1001931436)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .outboxReadDate(let date):
                return ("outboxReadDate", [("date", date as Any)])
    }
    }
    
        public static func parse_outboxReadDate(_ reader: BufferReader) -> OutboxReadDate? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.OutboxReadDate.outboxReadDate(date: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Page: TypeConstructorDescription {
        case page(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document], views: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .page(let flags, let url, let blocks, let photos, let documents, let views):
                    if boxed {
                        buffer.appendInt32(-1738178803)
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
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(views!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .page(let flags, let url, let blocks, let photos, let documents, let views):
                return ("page", [("flags", flags as Any), ("url", url as Any), ("blocks", blocks as Any), ("photos", photos as Any), ("documents", documents as Any), ("views", views as Any)])
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
            var _6: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Page.page(flags: _1!, url: _2!, blocks: _3!, photos: _4!, documents: _5!, views: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum PageBlock: TypeConstructorDescription {
        case pageBlockAnchor(name: String)
        case pageBlockAudio(audioId: Int64, caption: Api.PageCaption)
        case pageBlockAuthorDate(author: Api.RichText, publishedDate: Int32)
        case pageBlockBlockquote(text: Api.RichText, caption: Api.RichText)
        case pageBlockChannel(channel: Api.Chat)
        case pageBlockCollage(items: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockCover(cover: Api.PageBlock)
        case pageBlockDetails(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText)
        case pageBlockDivider
        case pageBlockEmbed(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption)
        case pageBlockEmbedPost(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockFooter(text: Api.RichText)
        case pageBlockHeader(text: Api.RichText)
        case pageBlockKicker(text: Api.RichText)
        case pageBlockList(items: [Api.PageListItem])
        case pageBlockMap(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption)
        case pageBlockOrderedList(items: [Api.PageListOrderedItem])
        case pageBlockParagraph(text: Api.RichText)
        case pageBlockPhoto(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?)
        case pageBlockPreformatted(text: Api.RichText, language: String)
        case pageBlockPullquote(text: Api.RichText, caption: Api.RichText)
        case pageBlockRelatedArticles(title: Api.RichText, articles: [Api.PageRelatedArticle])
        case pageBlockSlideshow(items: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockSubheader(text: Api.RichText)
        case pageBlockSubtitle(text: Api.RichText)
        case pageBlockTable(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow])
        case pageBlockTitle(text: Api.RichText)
        case pageBlockUnsupported
        case pageBlockVideo(flags: Int32, videoId: Int64, caption: Api.PageCaption)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pageBlockAnchor(let name):
                    if boxed {
                        buffer.appendInt32(-837994576)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    break
                case .pageBlockAudio(let audioId, let caption):
                    if boxed {
                        buffer.appendInt32(-2143067670)
                    }
                    serializeInt64(audioId, buffer: buffer, boxed: false)
                    caption.serialize(buffer, true)
                    break
                case .pageBlockAuthorDate(let author, let publishedDate):
                    if boxed {
                        buffer.appendInt32(-1162877472)
                    }
                    author.serialize(buffer, true)
                    serializeInt32(publishedDate, buffer: buffer, boxed: false)
                    break
                case .pageBlockBlockquote(let text, let caption):
                    if boxed {
                        buffer.appendInt32(641563686)
                    }
                    text.serialize(buffer, true)
                    caption.serialize(buffer, true)
                    break
                case .pageBlockChannel(let channel):
                    if boxed {
                        buffer.appendInt32(-283684427)
                    }
                    channel.serialize(buffer, true)
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
                case .pageBlockCover(let cover):
                    if boxed {
                        buffer.appendInt32(972174080)
                    }
                    cover.serialize(buffer, true)
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
                case .pageBlockDivider:
                    if boxed {
                        buffer.appendInt32(-618614392)
                    }
                    
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
                case .pageBlockFooter(let text):
                    if boxed {
                        buffer.appendInt32(1216809369)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockHeader(let text):
                    if boxed {
                        buffer.appendInt32(-1076861716)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockKicker(let text):
                    if boxed {
                        buffer.appendInt32(504660880)
                    }
                    text.serialize(buffer, true)
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
                case .pageBlockParagraph(let text):
                    if boxed {
                        buffer.appendInt32(1182402406)
                    }
                    text.serialize(buffer, true)
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
                case .pageBlockPreformatted(let text, let language):
                    if boxed {
                        buffer.appendInt32(-1066346178)
                    }
                    text.serialize(buffer, true)
                    serializeString(language, buffer: buffer, boxed: false)
                    break
                case .pageBlockPullquote(let text, let caption):
                    if boxed {
                        buffer.appendInt32(1329878739)
                    }
                    text.serialize(buffer, true)
                    caption.serialize(buffer, true)
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
                case .pageBlockSubheader(let text):
                    if boxed {
                        buffer.appendInt32(-248793375)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockSubtitle(let text):
                    if boxed {
                        buffer.appendInt32(-1879401953)
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
                case .pageBlockTitle(let text):
                    if boxed {
                        buffer.appendInt32(1890305021)
                    }
                    text.serialize(buffer, true)
                    break
                case .pageBlockUnsupported:
                    if boxed {
                        buffer.appendInt32(324435594)
                    }
                    
                    break
                case .pageBlockVideo(let flags, let videoId, let caption):
                    if boxed {
                        buffer.appendInt32(2089805750)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(videoId, buffer: buffer, boxed: false)
                    caption.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pageBlockAnchor(let name):
                return ("pageBlockAnchor", [("name", name as Any)])
                case .pageBlockAudio(let audioId, let caption):
                return ("pageBlockAudio", [("audioId", audioId as Any), ("caption", caption as Any)])
                case .pageBlockAuthorDate(let author, let publishedDate):
                return ("pageBlockAuthorDate", [("author", author as Any), ("publishedDate", publishedDate as Any)])
                case .pageBlockBlockquote(let text, let caption):
                return ("pageBlockBlockquote", [("text", text as Any), ("caption", caption as Any)])
                case .pageBlockChannel(let channel):
                return ("pageBlockChannel", [("channel", channel as Any)])
                case .pageBlockCollage(let items, let caption):
                return ("pageBlockCollage", [("items", items as Any), ("caption", caption as Any)])
                case .pageBlockCover(let cover):
                return ("pageBlockCover", [("cover", cover as Any)])
                case .pageBlockDetails(let flags, let blocks, let title):
                return ("pageBlockDetails", [("flags", flags as Any), ("blocks", blocks as Any), ("title", title as Any)])
                case .pageBlockDivider:
                return ("pageBlockDivider", [])
                case .pageBlockEmbed(let flags, let url, let html, let posterPhotoId, let w, let h, let caption):
                return ("pageBlockEmbed", [("flags", flags as Any), ("url", url as Any), ("html", html as Any), ("posterPhotoId", posterPhotoId as Any), ("w", w as Any), ("h", h as Any), ("caption", caption as Any)])
                case .pageBlockEmbedPost(let url, let webpageId, let authorPhotoId, let author, let date, let blocks, let caption):
                return ("pageBlockEmbedPost", [("url", url as Any), ("webpageId", webpageId as Any), ("authorPhotoId", authorPhotoId as Any), ("author", author as Any), ("date", date as Any), ("blocks", blocks as Any), ("caption", caption as Any)])
                case .pageBlockFooter(let text):
                return ("pageBlockFooter", [("text", text as Any)])
                case .pageBlockHeader(let text):
                return ("pageBlockHeader", [("text", text as Any)])
                case .pageBlockKicker(let text):
                return ("pageBlockKicker", [("text", text as Any)])
                case .pageBlockList(let items):
                return ("pageBlockList", [("items", items as Any)])
                case .pageBlockMap(let geo, let zoom, let w, let h, let caption):
                return ("pageBlockMap", [("geo", geo as Any), ("zoom", zoom as Any), ("w", w as Any), ("h", h as Any), ("caption", caption as Any)])
                case .pageBlockOrderedList(let items):
                return ("pageBlockOrderedList", [("items", items as Any)])
                case .pageBlockParagraph(let text):
                return ("pageBlockParagraph", [("text", text as Any)])
                case .pageBlockPhoto(let flags, let photoId, let caption, let url, let webpageId):
                return ("pageBlockPhoto", [("flags", flags as Any), ("photoId", photoId as Any), ("caption", caption as Any), ("url", url as Any), ("webpageId", webpageId as Any)])
                case .pageBlockPreformatted(let text, let language):
                return ("pageBlockPreformatted", [("text", text as Any), ("language", language as Any)])
                case .pageBlockPullquote(let text, let caption):
                return ("pageBlockPullquote", [("text", text as Any), ("caption", caption as Any)])
                case .pageBlockRelatedArticles(let title, let articles):
                return ("pageBlockRelatedArticles", [("title", title as Any), ("articles", articles as Any)])
                case .pageBlockSlideshow(let items, let caption):
                return ("pageBlockSlideshow", [("items", items as Any), ("caption", caption as Any)])
                case .pageBlockSubheader(let text):
                return ("pageBlockSubheader", [("text", text as Any)])
                case .pageBlockSubtitle(let text):
                return ("pageBlockSubtitle", [("text", text as Any)])
                case .pageBlockTable(let flags, let title, let rows):
                return ("pageBlockTable", [("flags", flags as Any), ("title", title as Any), ("rows", rows as Any)])
                case .pageBlockTitle(let text):
                return ("pageBlockTitle", [("text", text as Any)])
                case .pageBlockUnsupported:
                return ("pageBlockUnsupported", [])
                case .pageBlockVideo(let flags, let videoId, let caption):
                return ("pageBlockVideo", [("flags", flags as Any), ("videoId", videoId as Any), ("caption", caption as Any)])
    }
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
        public static func parse_pageBlockDivider(_ reader: BufferReader) -> PageBlock? {
            return Api.PageBlock.pageBlockDivider
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
        public static func parse_pageBlockUnsupported(_ reader: BufferReader) -> PageBlock? {
            return Api.PageBlock.pageBlockUnsupported
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
    
    }
}
