public extension Api {
    enum NearestDc: TypeConstructorDescription {
        public class Cons_nearestDc: TypeConstructorDescription {
            public var country: String
            public var thisDc: Int32
            public var nearestDc: Int32
            public init(country: String, thisDc: Int32, nearestDc: Int32) {
                self.country = country
                self.thisDc = thisDc
                self.nearestDc = nearestDc
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("nearestDc", [("country", ConstructorParameterDescription(self.country)), ("thisDc", ConstructorParameterDescription(self.thisDc)), ("nearestDc", ConstructorParameterDescription(self.nearestDc))])
            }
        }
        case nearestDc(Cons_nearestDc)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .nearestDc(let _data):
                if boxed {
                    buffer.appendInt32(-1910892683)
                }
                serializeString(_data.country, buffer: buffer, boxed: false)
                serializeInt32(_data.thisDc, buffer: buffer, boxed: false)
                serializeInt32(_data.nearestDc, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .nearestDc(let _data):
                return ("nearestDc", [("country", ConstructorParameterDescription(_data.country)), ("thisDc", ConstructorParameterDescription(_data.thisDc)), ("nearestDc", ConstructorParameterDescription(_data.nearestDc))])
            }
        }

        public static func parse_nearestDc(_ reader: BufferReader) -> NearestDc? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.NearestDc.nearestDc(Cons_nearestDc(country: _1!, thisDc: _2!, nearestDc: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum NotificationSound: TypeConstructorDescription {
        public class Cons_notificationSoundLocal: TypeConstructorDescription {
            public var title: String
            public var data: String
            public init(title: String, data: String) {
                self.title = title
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notificationSoundLocal", [("title", ConstructorParameterDescription(self.title)), ("data", ConstructorParameterDescription(self.data))])
            }
        }
        public class Cons_notificationSoundRingtone: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notificationSoundRingtone", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case notificationSoundDefault
        case notificationSoundLocal(Cons_notificationSoundLocal)
        case notificationSoundNone
        case notificationSoundRingtone(Cons_notificationSoundRingtone)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .notificationSoundDefault:
                if boxed {
                    buffer.appendInt32(-1746354498)
                }
                break
            case .notificationSoundLocal(let _data):
                if boxed {
                    buffer.appendInt32(-2096391452)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.data, buffer: buffer, boxed: false)
                break
            case .notificationSoundNone:
                if boxed {
                    buffer.appendInt32(1863070943)
                }
                break
            case .notificationSoundRingtone(let _data):
                if boxed {
                    buffer.appendInt32(-9666487)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .notificationSoundDefault:
                return ("notificationSoundDefault", [])
            case .notificationSoundLocal(let _data):
                return ("notificationSoundLocal", [("title", ConstructorParameterDescription(_data.title)), ("data", ConstructorParameterDescription(_data.data))])
            case .notificationSoundNone:
                return ("notificationSoundNone", [])
            case .notificationSoundRingtone(let _data):
                return ("notificationSoundRingtone", [("id", ConstructorParameterDescription(_data.id))])
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
                return Api.NotificationSound.notificationSoundLocal(Cons_notificationSoundLocal(title: _1!, data: _2!))
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
                return Api.NotificationSound.notificationSoundRingtone(Cons_notificationSoundRingtone(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum NotifyPeer: TypeConstructorDescription {
        public class Cons_notifyForumTopic: TypeConstructorDescription {
            public var peer: Api.Peer
            public var topMsgId: Int32
            public init(peer: Api.Peer, topMsgId: Int32) {
                self.peer = peer
                self.topMsgId = topMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notifyForumTopic", [("peer", ConstructorParameterDescription(self.peer)), ("topMsgId", ConstructorParameterDescription(self.topMsgId))])
            }
        }
        public class Cons_notifyPeer: TypeConstructorDescription {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notifyPeer", [("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        case notifyBroadcasts
        case notifyChats
        case notifyForumTopic(Cons_notifyForumTopic)
        case notifyPeer(Cons_notifyPeer)
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
            case .notifyForumTopic(let _data):
                if boxed {
                    buffer.appendInt32(577659656)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMsgId, buffer: buffer, boxed: false)
                break
            case .notifyPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1613493288)
                }
                _data.peer.serialize(buffer, true)
                break
            case .notifyUsers:
                if boxed {
                    buffer.appendInt32(-1261946036)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .notifyBroadcasts:
                return ("notifyBroadcasts", [])
            case .notifyChats:
                return ("notifyChats", [])
            case .notifyForumTopic(let _data):
                return ("notifyForumTopic", [("peer", ConstructorParameterDescription(_data.peer)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId))])
            case .notifyPeer(let _data):
                return ("notifyPeer", [("peer", ConstructorParameterDescription(_data.peer))])
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
                return Api.NotifyPeer.notifyForumTopic(Cons_notifyForumTopic(peer: _1!, topMsgId: _2!))
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
                return Api.NotifyPeer.notifyPeer(Cons_notifyPeer(peer: _1!))
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
        public class Cons_outboxReadDate: TypeConstructorDescription {
            public var date: Int32
            public init(date: Int32) {
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("outboxReadDate", [("date", ConstructorParameterDescription(self.date))])
            }
        }
        case outboxReadDate(Cons_outboxReadDate)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .outboxReadDate(let _data):
                if boxed {
                    buffer.appendInt32(1001931436)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .outboxReadDate(let _data):
                return ("outboxReadDate", [("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_outboxReadDate(_ reader: BufferReader) -> OutboxReadDate? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.OutboxReadDate.outboxReadDate(Cons_outboxReadDate(date: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Page: TypeConstructorDescription {
        public class Cons_page: TypeConstructorDescription {
            public var flags: Int32
            public var url: String
            public var blocks: [Api.PageBlock]
            public var photos: [Api.Photo]
            public var documents: [Api.Document]
            public var views: Int32?
            public init(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document], views: Int32?) {
                self.flags = flags
                self.url = url
                self.blocks = blocks
                self.photos = photos
                self.documents = documents
                self.views = views
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("page", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url)), ("blocks", ConstructorParameterDescription(self.blocks)), ("photos", ConstructorParameterDescription(self.photos)), ("documents", ConstructorParameterDescription(self.documents)), ("views", ConstructorParameterDescription(self.views))])
            }
        }
        case page(Cons_page)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .page(let _data):
                if boxed {
                    buffer.appendInt32(-1738178803)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.photos.count))
                for item in _data.photos {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documents.count))
                for item in _data.documents {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.views!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .page(let _data):
                return ("page", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("photos", ConstructorParameterDescription(_data.photos)), ("documents", ConstructorParameterDescription(_data.documents)), ("views", ConstructorParameterDescription(_data.views))])
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
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Page.page(Cons_page(flags: _1!, url: _2!, blocks: _3!, photos: _4!, documents: _5!, views: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum PageBlock: TypeConstructorDescription {
        public class Cons_pageBlockAnchor: TypeConstructorDescription {
            public var name: String
            public init(name: String) {
                self.name = name
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockAnchor", [("name", ConstructorParameterDescription(self.name))])
            }
        }
        public class Cons_pageBlockAudio: TypeConstructorDescription {
            public var audioId: Int64
            public var caption: Api.PageCaption
            public init(audioId: Int64, caption: Api.PageCaption) {
                self.audioId = audioId
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockAudio", [("audioId", ConstructorParameterDescription(self.audioId)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockAuthorDate: TypeConstructorDescription {
            public var author: Api.RichText
            public var publishedDate: Int32
            public init(author: Api.RichText, publishedDate: Int32) {
                self.author = author
                self.publishedDate = publishedDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockAuthorDate", [("author", ConstructorParameterDescription(self.author)), ("publishedDate", ConstructorParameterDescription(self.publishedDate))])
            }
        }
        public class Cons_pageBlockBlockquote: TypeConstructorDescription {
            public var text: Api.RichText
            public var caption: Api.RichText
            public init(text: Api.RichText, caption: Api.RichText) {
                self.text = text
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockBlockquote", [("text", ConstructorParameterDescription(self.text)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockChannel: TypeConstructorDescription {
            public var channel: Api.Chat
            public init(channel: Api.Chat) {
                self.channel = channel
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockChannel", [("channel", ConstructorParameterDescription(self.channel))])
            }
        }
        public class Cons_pageBlockCollage: TypeConstructorDescription {
            public var items: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(items: [Api.PageBlock], caption: Api.PageCaption) {
                self.items = items
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockCollage", [("items", ConstructorParameterDescription(self.items)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockCover: TypeConstructorDescription {
            public var cover: Api.PageBlock
            public init(cover: Api.PageBlock) {
                self.cover = cover
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockCover", [("cover", ConstructorParameterDescription(self.cover))])
            }
        }
        public class Cons_pageBlockDetails: TypeConstructorDescription {
            public var flags: Int32
            public var blocks: [Api.PageBlock]
            public var title: Api.RichText
            public init(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText) {
                self.flags = flags
                self.blocks = blocks
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockDetails", [("flags", ConstructorParameterDescription(self.flags)), ("blocks", ConstructorParameterDescription(self.blocks)), ("title", ConstructorParameterDescription(self.title))])
            }
        }
        public class Cons_pageBlockEmbed: TypeConstructorDescription {
            public var flags: Int32
            public var url: String?
            public var html: String?
            public var posterPhotoId: Int64?
            public var w: Int32?
            public var h: Int32?
            public var caption: Api.PageCaption
            public init(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption) {
                self.flags = flags
                self.url = url
                self.html = html
                self.posterPhotoId = posterPhotoId
                self.w = w
                self.h = h
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockEmbed", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url)), ("html", ConstructorParameterDescription(self.html)), ("posterPhotoId", ConstructorParameterDescription(self.posterPhotoId)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockEmbedPost: TypeConstructorDescription {
            public var url: String
            public var webpageId: Int64
            public var authorPhotoId: Int64
            public var author: String
            public var date: Int32
            public var blocks: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption) {
                self.url = url
                self.webpageId = webpageId
                self.authorPhotoId = authorPhotoId
                self.author = author
                self.date = date
                self.blocks = blocks
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockEmbedPost", [("url", ConstructorParameterDescription(self.url)), ("webpageId", ConstructorParameterDescription(self.webpageId)), ("authorPhotoId", ConstructorParameterDescription(self.authorPhotoId)), ("author", ConstructorParameterDescription(self.author)), ("date", ConstructorParameterDescription(self.date)), ("blocks", ConstructorParameterDescription(self.blocks)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockFooter: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockFooter", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeader: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeader", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockKicker: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockKicker", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockList: TypeConstructorDescription {
            public var items: [Api.PageListItem]
            public init(items: [Api.PageListItem]) {
                self.items = items
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockList", [("items", ConstructorParameterDescription(self.items))])
            }
        }
        public class Cons_pageBlockMap: TypeConstructorDescription {
            public var geo: Api.GeoPoint
            public var zoom: Int32
            public var w: Int32
            public var h: Int32
            public var caption: Api.PageCaption
            public init(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption) {
                self.geo = geo
                self.zoom = zoom
                self.w = w
                self.h = h
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockMap", [("geo", ConstructorParameterDescription(self.geo)), ("zoom", ConstructorParameterDescription(self.zoom)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockOrderedList: TypeConstructorDescription {
            public var items: [Api.PageListOrderedItem]
            public init(items: [Api.PageListOrderedItem]) {
                self.items = items
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockOrderedList", [("items", ConstructorParameterDescription(self.items))])
            }
        }
        public class Cons_pageBlockParagraph: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockParagraph", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockPhoto: TypeConstructorDescription {
            public var flags: Int32
            public var photoId: Int64
            public var caption: Api.PageCaption
            public var url: String?
            public var webpageId: Int64?
            public init(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?) {
                self.flags = flags
                self.photoId = photoId
                self.caption = caption
                self.url = url
                self.webpageId = webpageId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockPhoto", [("flags", ConstructorParameterDescription(self.flags)), ("photoId", ConstructorParameterDescription(self.photoId)), ("caption", ConstructorParameterDescription(self.caption)), ("url", ConstructorParameterDescription(self.url)), ("webpageId", ConstructorParameterDescription(self.webpageId))])
            }
        }
        public class Cons_pageBlockPreformatted: TypeConstructorDescription {
            public var text: Api.RichText
            public var language: String
            public init(text: Api.RichText, language: String) {
                self.text = text
                self.language = language
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockPreformatted", [("text", ConstructorParameterDescription(self.text)), ("language", ConstructorParameterDescription(self.language))])
            }
        }
        public class Cons_pageBlockPullquote: TypeConstructorDescription {
            public var text: Api.RichText
            public var caption: Api.RichText
            public init(text: Api.RichText, caption: Api.RichText) {
                self.text = text
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockPullquote", [("text", ConstructorParameterDescription(self.text)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockRelatedArticles: TypeConstructorDescription {
            public var title: Api.RichText
            public var articles: [Api.PageRelatedArticle]
            public init(title: Api.RichText, articles: [Api.PageRelatedArticle]) {
                self.title = title
                self.articles = articles
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockRelatedArticles", [("title", ConstructorParameterDescription(self.title)), ("articles", ConstructorParameterDescription(self.articles))])
            }
        }
        public class Cons_pageBlockSlideshow: TypeConstructorDescription {
            public var items: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(items: [Api.PageBlock], caption: Api.PageCaption) {
                self.items = items
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockSlideshow", [("items", ConstructorParameterDescription(self.items)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockSubheader: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockSubheader", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockSubtitle: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockSubtitle", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockTable: TypeConstructorDescription {
            public var flags: Int32
            public var title: Api.RichText
            public var rows: [Api.PageTableRow]
            public init(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow]) {
                self.flags = flags
                self.title = title
                self.rows = rows
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockTable", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("rows", ConstructorParameterDescription(self.rows))])
            }
        }
        public class Cons_pageBlockTitle: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockTitle", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockVideo: TypeConstructorDescription {
            public var flags: Int32
            public var videoId: Int64
            public var caption: Api.PageCaption
            public init(flags: Int32, videoId: Int64, caption: Api.PageCaption) {
                self.flags = flags
                self.videoId = videoId
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockVideo", [("flags", ConstructorParameterDescription(self.flags)), ("videoId", ConstructorParameterDescription(self.videoId)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        case pageBlockAnchor(Cons_pageBlockAnchor)
        case pageBlockAudio(Cons_pageBlockAudio)
        case pageBlockAuthorDate(Cons_pageBlockAuthorDate)
        case pageBlockBlockquote(Cons_pageBlockBlockquote)
        case pageBlockChannel(Cons_pageBlockChannel)
        case pageBlockCollage(Cons_pageBlockCollage)
        case pageBlockCover(Cons_pageBlockCover)
        case pageBlockDetails(Cons_pageBlockDetails)
        case pageBlockDivider
        case pageBlockEmbed(Cons_pageBlockEmbed)
        case pageBlockEmbedPost(Cons_pageBlockEmbedPost)
        case pageBlockFooter(Cons_pageBlockFooter)
        case pageBlockHeader(Cons_pageBlockHeader)
        case pageBlockKicker(Cons_pageBlockKicker)
        case pageBlockList(Cons_pageBlockList)
        case pageBlockMap(Cons_pageBlockMap)
        case pageBlockOrderedList(Cons_pageBlockOrderedList)
        case pageBlockParagraph(Cons_pageBlockParagraph)
        case pageBlockPhoto(Cons_pageBlockPhoto)
        case pageBlockPreformatted(Cons_pageBlockPreformatted)
        case pageBlockPullquote(Cons_pageBlockPullquote)
        case pageBlockRelatedArticles(Cons_pageBlockRelatedArticles)
        case pageBlockSlideshow(Cons_pageBlockSlideshow)
        case pageBlockSubheader(Cons_pageBlockSubheader)
        case pageBlockSubtitle(Cons_pageBlockSubtitle)
        case pageBlockTable(Cons_pageBlockTable)
        case pageBlockTitle(Cons_pageBlockTitle)
        case pageBlockUnsupported
        case pageBlockVideo(Cons_pageBlockVideo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .pageBlockAnchor(let _data):
                if boxed {
                    buffer.appendInt32(-837994576)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                break
            case .pageBlockAudio(let _data):
                if boxed {
                    buffer.appendInt32(-2143067670)
                }
                serializeInt64(_data.audioId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockAuthorDate(let _data):
                if boxed {
                    buffer.appendInt32(-1162877472)
                }
                _data.author.serialize(buffer, true)
                serializeInt32(_data.publishedDate, buffer: buffer, boxed: false)
                break
            case .pageBlockBlockquote(let _data):
                if boxed {
                    buffer.appendInt32(641563686)
                }
                _data.text.serialize(buffer, true)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockChannel(let _data):
                if boxed {
                    buffer.appendInt32(-283684427)
                }
                _data.channel.serialize(buffer, true)
                break
            case .pageBlockCollage(let _data):
                if boxed {
                    buffer.appendInt32(1705048653)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockCover(let _data):
                if boxed {
                    buffer.appendInt32(972174080)
                }
                _data.cover.serialize(buffer, true)
                break
            case .pageBlockDetails(let _data):
                if boxed {
                    buffer.appendInt32(1987480557)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                _data.title.serialize(buffer, true)
                break
            case .pageBlockDivider:
                if boxed {
                    buffer.appendInt32(-618614392)
                }
                break
            case .pageBlockEmbed(let _data):
                if boxed {
                    buffer.appendInt32(-1468953147)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.html!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.posterPhotoId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.w!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.h!, buffer: buffer, boxed: false)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockEmbedPost(let _data):
                if boxed {
                    buffer.appendInt32(-229005301)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.webpageId, buffer: buffer, boxed: false)
                serializeInt64(_data.authorPhotoId, buffer: buffer, boxed: false)
                serializeString(_data.author, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockFooter(let _data):
                if boxed {
                    buffer.appendInt32(1216809369)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeader(let _data):
                if boxed {
                    buffer.appendInt32(-1076861716)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockKicker(let _data):
                if boxed {
                    buffer.appendInt32(504660880)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockList(let _data):
                if boxed {
                    buffer.appendInt32(-454524911)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockMap(let _data):
                if boxed {
                    buffer.appendInt32(-1538310410)
                }
                _data.geo.serialize(buffer, true)
                serializeInt32(_data.zoom, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockOrderedList(let _data):
                if boxed {
                    buffer.appendInt32(-1702174239)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockParagraph(let _data):
                if boxed {
                    buffer.appendInt32(1182402406)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockPhoto(let _data):
                if boxed {
                    buffer.appendInt32(391759200)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.photoId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.webpageId!, buffer: buffer, boxed: false)
                }
                break
            case .pageBlockPreformatted(let _data):
                if boxed {
                    buffer.appendInt32(-1066346178)
                }
                _data.text.serialize(buffer, true)
                serializeString(_data.language, buffer: buffer, boxed: false)
                break
            case .pageBlockPullquote(let _data):
                if boxed {
                    buffer.appendInt32(1329878739)
                }
                _data.text.serialize(buffer, true)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockRelatedArticles(let _data):
                if boxed {
                    buffer.appendInt32(370236054)
                }
                _data.title.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.articles.count))
                for item in _data.articles {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockSlideshow(let _data):
                if boxed {
                    buffer.appendInt32(52401552)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockSubheader(let _data):
                if boxed {
                    buffer.appendInt32(-248793375)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockSubtitle(let _data):
                if boxed {
                    buffer.appendInt32(-1879401953)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockTable(let _data):
                if boxed {
                    buffer.appendInt32(-1085412734)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rows.count))
                for item in _data.rows {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockTitle(let _data):
                if boxed {
                    buffer.appendInt32(1890305021)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockUnsupported:
                if boxed {
                    buffer.appendInt32(324435594)
                }
                break
            case .pageBlockVideo(let _data):
                if boxed {
                    buffer.appendInt32(2089805750)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.videoId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .pageBlockAnchor(let _data):
                return ("pageBlockAnchor", [("name", ConstructorParameterDescription(_data.name))])
            case .pageBlockAudio(let _data):
                return ("pageBlockAudio", [("audioId", ConstructorParameterDescription(_data.audioId)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockAuthorDate(let _data):
                return ("pageBlockAuthorDate", [("author", ConstructorParameterDescription(_data.author)), ("publishedDate", ConstructorParameterDescription(_data.publishedDate))])
            case .pageBlockBlockquote(let _data):
                return ("pageBlockBlockquote", [("text", ConstructorParameterDescription(_data.text)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockChannel(let _data):
                return ("pageBlockChannel", [("channel", ConstructorParameterDescription(_data.channel))])
            case .pageBlockCollage(let _data):
                return ("pageBlockCollage", [("items", ConstructorParameterDescription(_data.items)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockCover(let _data):
                return ("pageBlockCover", [("cover", ConstructorParameterDescription(_data.cover))])
            case .pageBlockDetails(let _data):
                return ("pageBlockDetails", [("flags", ConstructorParameterDescription(_data.flags)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("title", ConstructorParameterDescription(_data.title))])
            case .pageBlockDivider:
                return ("pageBlockDivider", [])
            case .pageBlockEmbed(let _data):
                return ("pageBlockEmbed", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url)), ("html", ConstructorParameterDescription(_data.html)), ("posterPhotoId", ConstructorParameterDescription(_data.posterPhotoId)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockEmbedPost(let _data):
                return ("pageBlockEmbedPost", [("url", ConstructorParameterDescription(_data.url)), ("webpageId", ConstructorParameterDescription(_data.webpageId)), ("authorPhotoId", ConstructorParameterDescription(_data.authorPhotoId)), ("author", ConstructorParameterDescription(_data.author)), ("date", ConstructorParameterDescription(_data.date)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockFooter(let _data):
                return ("pageBlockFooter", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeader(let _data):
                return ("pageBlockHeader", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockKicker(let _data):
                return ("pageBlockKicker", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockList(let _data):
                return ("pageBlockList", [("items", ConstructorParameterDescription(_data.items))])
            case .pageBlockMap(let _data):
                return ("pageBlockMap", [("geo", ConstructorParameterDescription(_data.geo)), ("zoom", ConstructorParameterDescription(_data.zoom)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockOrderedList(let _data):
                return ("pageBlockOrderedList", [("items", ConstructorParameterDescription(_data.items))])
            case .pageBlockParagraph(let _data):
                return ("pageBlockParagraph", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockPhoto(let _data):
                return ("pageBlockPhoto", [("flags", ConstructorParameterDescription(_data.flags)), ("photoId", ConstructorParameterDescription(_data.photoId)), ("caption", ConstructorParameterDescription(_data.caption)), ("url", ConstructorParameterDescription(_data.url)), ("webpageId", ConstructorParameterDescription(_data.webpageId))])
            case .pageBlockPreformatted(let _data):
                return ("pageBlockPreformatted", [("text", ConstructorParameterDescription(_data.text)), ("language", ConstructorParameterDescription(_data.language))])
            case .pageBlockPullquote(let _data):
                return ("pageBlockPullquote", [("text", ConstructorParameterDescription(_data.text)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockRelatedArticles(let _data):
                return ("pageBlockRelatedArticles", [("title", ConstructorParameterDescription(_data.title)), ("articles", ConstructorParameterDescription(_data.articles))])
            case .pageBlockSlideshow(let _data):
                return ("pageBlockSlideshow", [("items", ConstructorParameterDescription(_data.items)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockSubheader(let _data):
                return ("pageBlockSubheader", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockSubtitle(let _data):
                return ("pageBlockSubtitle", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockTable(let _data):
                return ("pageBlockTable", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("rows", ConstructorParameterDescription(_data.rows))])
            case .pageBlockTitle(let _data):
                return ("pageBlockTitle", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockUnsupported:
                return ("pageBlockUnsupported", [])
            case .pageBlockVideo(let _data):
                return ("pageBlockVideo", [("flags", ConstructorParameterDescription(_data.flags)), ("videoId", ConstructorParameterDescription(_data.videoId)), ("caption", ConstructorParameterDescription(_data.caption))])
            }
        }

        public static func parse_pageBlockAnchor(_ reader: BufferReader) -> PageBlock? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockAnchor(Cons_pageBlockAnchor(name: _1!))
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
                return Api.PageBlock.pageBlockAudio(Cons_pageBlockAudio(audioId: _1!, caption: _2!))
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
                return Api.PageBlock.pageBlockAuthorDate(Cons_pageBlockAuthorDate(author: _1!, publishedDate: _2!))
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
                return Api.PageBlock.pageBlockBlockquote(Cons_pageBlockBlockquote(text: _1!, caption: _2!))
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
                return Api.PageBlock.pageBlockChannel(Cons_pageBlockChannel(channel: _1!))
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
                return Api.PageBlock.pageBlockCollage(Cons_pageBlockCollage(items: _1!, caption: _2!))
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
                return Api.PageBlock.pageBlockCover(Cons_pageBlockCover(cover: _1!))
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
                return Api.PageBlock.pageBlockDetails(Cons_pageBlockDetails(flags: _1!, blocks: _2!, title: _3!))
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
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _6 = reader.readInt32()
            }
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
                return Api.PageBlock.pageBlockEmbed(Cons_pageBlockEmbed(flags: _1!, url: _2, html: _3, posterPhotoId: _4, w: _5, h: _6, caption: _7!))
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
                return Api.PageBlock.pageBlockEmbedPost(Cons_pageBlockEmbedPost(url: _1!, webpageId: _2!, authorPhotoId: _3!, author: _4!, date: _5!, blocks: _6!, caption: _7!))
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
                return Api.PageBlock.pageBlockFooter(Cons_pageBlockFooter(text: _1!))
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
                return Api.PageBlock.pageBlockHeader(Cons_pageBlockHeader(text: _1!))
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
                return Api.PageBlock.pageBlockKicker(Cons_pageBlockKicker(text: _1!))
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
                return Api.PageBlock.pageBlockList(Cons_pageBlockList(items: _1!))
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
                return Api.PageBlock.pageBlockMap(Cons_pageBlockMap(geo: _1!, zoom: _2!, w: _3!, h: _4!, caption: _5!))
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
                return Api.PageBlock.pageBlockOrderedList(Cons_pageBlockOrderedList(items: _1!))
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
                return Api.PageBlock.pageBlockParagraph(Cons_pageBlockParagraph(text: _1!))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PageBlock.pageBlockPhoto(Cons_pageBlockPhoto(flags: _1!, photoId: _2!, caption: _3!, url: _4, webpageId: _5))
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
                return Api.PageBlock.pageBlockPreformatted(Cons_pageBlockPreformatted(text: _1!, language: _2!))
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
                return Api.PageBlock.pageBlockPullquote(Cons_pageBlockPullquote(text: _1!, caption: _2!))
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
                return Api.PageBlock.pageBlockRelatedArticles(Cons_pageBlockRelatedArticles(title: _1!, articles: _2!))
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
                return Api.PageBlock.pageBlockSlideshow(Cons_pageBlockSlideshow(items: _1!, caption: _2!))
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
                return Api.PageBlock.pageBlockSubheader(Cons_pageBlockSubheader(text: _1!))
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
                return Api.PageBlock.pageBlockSubtitle(Cons_pageBlockSubtitle(text: _1!))
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
                return Api.PageBlock.pageBlockTable(Cons_pageBlockTable(flags: _1!, title: _2!, rows: _3!))
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
                return Api.PageBlock.pageBlockTitle(Cons_pageBlockTitle(text: _1!))
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
                return Api.PageBlock.pageBlockVideo(Cons_pageBlockVideo(flags: _1!, videoId: _2!, caption: _3!))
            }
            else {
                return nil
            }
        }
    }
}
