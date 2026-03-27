public extension Api {
    indirect enum InputMedia: TypeConstructorDescription {
        public class Cons_inputMediaContact: TypeConstructorDescription {
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public init(phoneNumber: String, firstName: String, lastName: String, vcard: String) {
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaContact", [("phoneNumber", ConstructorParameterDescription(self.phoneNumber)), ("firstName", ConstructorParameterDescription(self.firstName)), ("lastName", ConstructorParameterDescription(self.lastName)), ("vcard", ConstructorParameterDescription(self.vcard))])
            }
        }
        public class Cons_inputMediaDice: TypeConstructorDescription {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaDice", [("emoticon", ConstructorParameterDescription(self.emoticon))])
            }
        }
        public class Cons_inputMediaDocument: TypeConstructorDescription {
            public var flags: Int32
            public var id: Api.InputDocument
            public var videoCover: Api.InputPhoto?
            public var videoTimestamp: Int32?
            public var ttlSeconds: Int32?
            public var query: String?
            public init(flags: Int32, id: Api.InputDocument, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?, query: String?) {
                self.flags = flags
                self.id = id
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
                self.ttlSeconds = ttlSeconds
                self.query = query
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaDocument", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("videoCover", ConstructorParameterDescription(self.videoCover)), ("videoTimestamp", ConstructorParameterDescription(self.videoTimestamp)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds)), ("query", ConstructorParameterDescription(self.query))])
            }
        }
        public class Cons_inputMediaDocumentExternal: TypeConstructorDescription {
            public var flags: Int32
            public var url: String
            public var ttlSeconds: Int32?
            public var videoCover: Api.InputPhoto?
            public var videoTimestamp: Int32?
            public init(flags: Int32, url: String, ttlSeconds: Int32?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?) {
                self.flags = flags
                self.url = url
                self.ttlSeconds = ttlSeconds
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaDocumentExternal", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds)), ("videoCover", ConstructorParameterDescription(self.videoCover)), ("videoTimestamp", ConstructorParameterDescription(self.videoTimestamp))])
            }
        }
        public class Cons_inputMediaGame: TypeConstructorDescription {
            public var id: Api.InputGame
            public init(id: Api.InputGame) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaGame", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputMediaGeoLive: TypeConstructorDescription {
            public var flags: Int32
            public var geoPoint: Api.InputGeoPoint
            public var heading: Int32?
            public var period: Int32?
            public var proximityNotificationRadius: Int32?
            public init(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaGeoLive", [("flags", ConstructorParameterDescription(self.flags)), ("geoPoint", ConstructorParameterDescription(self.geoPoint)), ("heading", ConstructorParameterDescription(self.heading)), ("period", ConstructorParameterDescription(self.period)), ("proximityNotificationRadius", ConstructorParameterDescription(self.proximityNotificationRadius))])
            }
        }
        public class Cons_inputMediaGeoPoint: TypeConstructorDescription {
            public var geoPoint: Api.InputGeoPoint
            public init(geoPoint: Api.InputGeoPoint) {
                self.geoPoint = geoPoint
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaGeoPoint", [("geoPoint", ConstructorParameterDescription(self.geoPoint))])
            }
        }
        public class Cons_inputMediaInvoice: TypeConstructorDescription {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.InputWebDocument?
            public var invoice: Api.Invoice
            public var payload: Buffer
            public var provider: String?
            public var providerData: Api.DataJSON
            public var startParam: String?
            public var extendedMedia: Api.InputMedia?
            public init(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String?, providerData: Api.DataJSON, startParam: String?, extendedMedia: Api.InputMedia?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.payload = payload
                self.provider = provider
                self.providerData = providerData
                self.startParam = startParam
                self.extendedMedia = extendedMedia
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaInvoice", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("description", ConstructorParameterDescription(self.description)), ("photo", ConstructorParameterDescription(self.photo)), ("invoice", ConstructorParameterDescription(self.invoice)), ("payload", ConstructorParameterDescription(self.payload)), ("provider", ConstructorParameterDescription(self.provider)), ("providerData", ConstructorParameterDescription(self.providerData)), ("startParam", ConstructorParameterDescription(self.startParam)), ("extendedMedia", ConstructorParameterDescription(self.extendedMedia))])
            }
        }
        public class Cons_inputMediaPaidMedia: TypeConstructorDescription {
            public var flags: Int32
            public var starsAmount: Int64
            public var extendedMedia: [Api.InputMedia]
            public var payload: String?
            public init(flags: Int32, starsAmount: Int64, extendedMedia: [Api.InputMedia], payload: String?) {
                self.flags = flags
                self.starsAmount = starsAmount
                self.extendedMedia = extendedMedia
                self.payload = payload
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaPaidMedia", [("flags", ConstructorParameterDescription(self.flags)), ("starsAmount", ConstructorParameterDescription(self.starsAmount)), ("extendedMedia", ConstructorParameterDescription(self.extendedMedia)), ("payload", ConstructorParameterDescription(self.payload))])
            }
        }
        public class Cons_inputMediaPhoto: TypeConstructorDescription {
            public var flags: Int32
            public var id: Api.InputPhoto
            public var ttlSeconds: Int32?
            public var video: Api.InputDocument?
            public init(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?, video: Api.InputDocument?) {
                self.flags = flags
                self.id = id
                self.ttlSeconds = ttlSeconds
                self.video = video
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaPhoto", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds)), ("video", ConstructorParameterDescription(self.video))])
            }
        }
        public class Cons_inputMediaPhotoExternal: TypeConstructorDescription {
            public var flags: Int32
            public var url: String
            public var ttlSeconds: Int32?
            public init(flags: Int32, url: String, ttlSeconds: Int32?) {
                self.flags = flags
                self.url = url
                self.ttlSeconds = ttlSeconds
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaPhotoExternal", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds))])
            }
        }
        public class Cons_inputMediaPoll: TypeConstructorDescription {
            public var flags: Int32
            public var poll: Api.Poll
            public var correctAnswers: [Int32]?
            public var attachedMedia: Api.InputMedia?
            public var solution: String?
            public var solutionEntities: [Api.MessageEntity]?
            public var solutionMedia: Api.InputMedia?
            public init(flags: Int32, poll: Api.Poll, correctAnswers: [Int32]?, attachedMedia: Api.InputMedia?, solution: String?, solutionEntities: [Api.MessageEntity]?, solutionMedia: Api.InputMedia?) {
                self.flags = flags
                self.poll = poll
                self.correctAnswers = correctAnswers
                self.attachedMedia = attachedMedia
                self.solution = solution
                self.solutionEntities = solutionEntities
                self.solutionMedia = solutionMedia
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaPoll", [("flags", ConstructorParameterDescription(self.flags)), ("poll", ConstructorParameterDescription(self.poll)), ("correctAnswers", ConstructorParameterDescription(self.correctAnswers)), ("attachedMedia", ConstructorParameterDescription(self.attachedMedia)), ("solution", ConstructorParameterDescription(self.solution)), ("solutionEntities", ConstructorParameterDescription(self.solutionEntities)), ("solutionMedia", ConstructorParameterDescription(self.solutionMedia))])
            }
        }
        public class Cons_inputMediaStakeDice: TypeConstructorDescription {
            public var gameHash: String
            public var tonAmount: Int64
            public var clientSeed: Buffer
            public init(gameHash: String, tonAmount: Int64, clientSeed: Buffer) {
                self.gameHash = gameHash
                self.tonAmount = tonAmount
                self.clientSeed = clientSeed
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaStakeDice", [("gameHash", ConstructorParameterDescription(self.gameHash)), ("tonAmount", ConstructorParameterDescription(self.tonAmount)), ("clientSeed", ConstructorParameterDescription(self.clientSeed))])
            }
        }
        public class Cons_inputMediaStory: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var id: Int32
            public init(peer: Api.InputPeer, id: Int32) {
                self.peer = peer
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaStory", [("peer", ConstructorParameterDescription(self.peer)), ("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputMediaTodo: TypeConstructorDescription {
            public var todo: Api.TodoList
            public init(todo: Api.TodoList) {
                self.todo = todo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaTodo", [("todo", ConstructorParameterDescription(self.todo))])
            }
        }
        public class Cons_inputMediaUploadedDocument: TypeConstructorDescription {
            public var flags: Int32
            public var file: Api.InputFile
            public var thumb: Api.InputFile?
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public var stickers: [Api.InputDocument]?
            public var videoCover: Api.InputPhoto?
            public var videoTimestamp: Int32?
            public var ttlSeconds: Int32?
            public init(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?) {
                self.flags = flags
                self.file = file
                self.thumb = thumb
                self.mimeType = mimeType
                self.attributes = attributes
                self.stickers = stickers
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
                self.ttlSeconds = ttlSeconds
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaUploadedDocument", [("flags", ConstructorParameterDescription(self.flags)), ("file", ConstructorParameterDescription(self.file)), ("thumb", ConstructorParameterDescription(self.thumb)), ("mimeType", ConstructorParameterDescription(self.mimeType)), ("attributes", ConstructorParameterDescription(self.attributes)), ("stickers", ConstructorParameterDescription(self.stickers)), ("videoCover", ConstructorParameterDescription(self.videoCover)), ("videoTimestamp", ConstructorParameterDescription(self.videoTimestamp)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds))])
            }
        }
        public class Cons_inputMediaUploadedPhoto: TypeConstructorDescription {
            public var flags: Int32
            public var file: Api.InputFile
            public var stickers: [Api.InputDocument]?
            public var ttlSeconds: Int32?
            public var video: Api.InputDocument?
            public init(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?, video: Api.InputDocument?) {
                self.flags = flags
                self.file = file
                self.stickers = stickers
                self.ttlSeconds = ttlSeconds
                self.video = video
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaUploadedPhoto", [("flags", ConstructorParameterDescription(self.flags)), ("file", ConstructorParameterDescription(self.file)), ("stickers", ConstructorParameterDescription(self.stickers)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds)), ("video", ConstructorParameterDescription(self.video))])
            }
        }
        public class Cons_inputMediaVenue: TypeConstructorDescription {
            public var geoPoint: Api.InputGeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.geoPoint = geoPoint
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaVenue", [("geoPoint", ConstructorParameterDescription(self.geoPoint)), ("title", ConstructorParameterDescription(self.title)), ("address", ConstructorParameterDescription(self.address)), ("provider", ConstructorParameterDescription(self.provider)), ("venueId", ConstructorParameterDescription(self.venueId)), ("venueType", ConstructorParameterDescription(self.venueType))])
            }
        }
        public class Cons_inputMediaWebPage: TypeConstructorDescription {
            public var flags: Int32
            public var url: String
            public init(flags: Int32, url: String) {
                self.flags = flags
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaWebPage", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        case inputMediaContact(Cons_inputMediaContact)
        case inputMediaDice(Cons_inputMediaDice)
        case inputMediaDocument(Cons_inputMediaDocument)
        case inputMediaDocumentExternal(Cons_inputMediaDocumentExternal)
        case inputMediaEmpty
        case inputMediaGame(Cons_inputMediaGame)
        case inputMediaGeoLive(Cons_inputMediaGeoLive)
        case inputMediaGeoPoint(Cons_inputMediaGeoPoint)
        case inputMediaInvoice(Cons_inputMediaInvoice)
        case inputMediaPaidMedia(Cons_inputMediaPaidMedia)
        case inputMediaPhoto(Cons_inputMediaPhoto)
        case inputMediaPhotoExternal(Cons_inputMediaPhotoExternal)
        case inputMediaPoll(Cons_inputMediaPoll)
        case inputMediaStakeDice(Cons_inputMediaStakeDice)
        case inputMediaStory(Cons_inputMediaStory)
        case inputMediaTodo(Cons_inputMediaTodo)
        case inputMediaUploadedDocument(Cons_inputMediaUploadedDocument)
        case inputMediaUploadedPhoto(Cons_inputMediaUploadedPhoto)
        case inputMediaVenue(Cons_inputMediaVenue)
        case inputMediaWebPage(Cons_inputMediaWebPage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMediaContact(let _data):
                if boxed {
                    buffer.appendInt32(-122978821)
                }
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                serializeString(_data.vcard, buffer: buffer, boxed: false)
                break
            case .inputMediaDice(let _data):
                if boxed {
                    buffer.appendInt32(-428884101)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .inputMediaDocument(let _data):
                if boxed {
                    buffer.appendInt32(-1468646731)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.id.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.videoCover!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.videoTimestamp!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.query!, buffer: buffer, boxed: false)
                }
                break
            case .inputMediaDocumentExternal(let _data):
                if boxed {
                    buffer.appendInt32(2006319353)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.videoCover!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.videoTimestamp!, buffer: buffer, boxed: false)
                }
                break
            case .inputMediaEmpty:
                if boxed {
                    buffer.appendInt32(-1771768449)
                }
                break
            case .inputMediaGame(let _data):
                if boxed {
                    buffer.appendInt32(-750828557)
                }
                _data.id.serialize(buffer, true)
                break
            case .inputMediaGeoLive(let _data):
                if boxed {
                    buffer.appendInt32(-1759532989)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.geoPoint.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.heading!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.period!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.proximityNotificationRadius!, buffer: buffer, boxed: false)
                }
                break
            case .inputMediaGeoPoint(let _data):
                if boxed {
                    buffer.appendInt32(-104578748)
                }
                _data.geoPoint.serialize(buffer, true)
                break
            case .inputMediaInvoice(let _data):
                if boxed {
                    buffer.appendInt32(1080028941)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                _data.invoice.serialize(buffer, true)
                serializeBytes(_data.payload, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.provider!, buffer: buffer, boxed: false)
                }
                _data.providerData.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.startParam!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.extendedMedia!.serialize(buffer, true)
                }
                break
            case .inputMediaPaidMedia(let _data):
                if boxed {
                    buffer.appendInt32(-1005571194)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.extendedMedia.count))
                for item in _data.extendedMedia {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.payload!, buffer: buffer, boxed: false)
                }
                break
            case .inputMediaPhoto(let _data):
                if boxed {
                    buffer.appendInt32(-475053004)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.id.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.video!.serialize(buffer, true)
                }
                break
            case .inputMediaPhotoExternal(let _data):
                if boxed {
                    buffer.appendInt32(-440664550)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                break
            case .inputMediaPoll(let _data):
                if boxed {
                    buffer.appendInt32(-2009448184)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.poll.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.correctAnswers!.count))
                    for item in _data.correctAnswers! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.attachedMedia!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.solution!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.solutionEntities!.count))
                    for item in _data.solutionEntities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.solutionMedia!.serialize(buffer, true)
                }
                break
            case .inputMediaStakeDice(let _data):
                if boxed {
                    buffer.appendInt32(-207018934)
                }
                serializeString(_data.gameHash, buffer: buffer, boxed: false)
                serializeInt64(_data.tonAmount, buffer: buffer, boxed: false)
                serializeBytes(_data.clientSeed, buffer: buffer, boxed: false)
                break
            case .inputMediaStory(let _data):
                if boxed {
                    buffer.appendInt32(-1979852936)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .inputMediaTodo(let _data):
                if boxed {
                    buffer.appendInt32(-1614454818)
                }
                _data.todo.serialize(buffer, true)
                break
            case .inputMediaUploadedDocument(let _data):
                if boxed {
                    buffer.appendInt32(58495792)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.file.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.thumb!.serialize(buffer, true)
                }
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.stickers!.count))
                    for item in _data.stickers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.videoCover!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.videoTimestamp!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                break
            case .inputMediaUploadedPhoto(let _data):
                if boxed {
                    buffer.appendInt32(2105767386)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.file.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.stickers!.count))
                    for item in _data.stickers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.video!.serialize(buffer, true)
                }
                break
            case .inputMediaVenue(let _data):
                if boxed {
                    buffer.appendInt32(-1052959727)
                }
                _data.geoPoint.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.venueId, buffer: buffer, boxed: false)
                serializeString(_data.venueType, buffer: buffer, boxed: false)
                break
            case .inputMediaWebPage(let _data):
                if boxed {
                    buffer.appendInt32(-1038383031)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMediaContact(let _data):
                return ("inputMediaContact", [("phoneNumber", ConstructorParameterDescription(_data.phoneNumber)), ("firstName", ConstructorParameterDescription(_data.firstName)), ("lastName", ConstructorParameterDescription(_data.lastName)), ("vcard", ConstructorParameterDescription(_data.vcard))])
            case .inputMediaDice(let _data):
                return ("inputMediaDice", [("emoticon", ConstructorParameterDescription(_data.emoticon))])
            case .inputMediaDocument(let _data):
                return ("inputMediaDocument", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("videoCover", ConstructorParameterDescription(_data.videoCover)), ("videoTimestamp", ConstructorParameterDescription(_data.videoTimestamp)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds)), ("query", ConstructorParameterDescription(_data.query))])
            case .inputMediaDocumentExternal(let _data):
                return ("inputMediaDocumentExternal", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds)), ("videoCover", ConstructorParameterDescription(_data.videoCover)), ("videoTimestamp", ConstructorParameterDescription(_data.videoTimestamp))])
            case .inputMediaEmpty:
                return ("inputMediaEmpty", [])
            case .inputMediaGame(let _data):
                return ("inputMediaGame", [("id", ConstructorParameterDescription(_data.id))])
            case .inputMediaGeoLive(let _data):
                return ("inputMediaGeoLive", [("flags", ConstructorParameterDescription(_data.flags)), ("geoPoint", ConstructorParameterDescription(_data.geoPoint)), ("heading", ConstructorParameterDescription(_data.heading)), ("period", ConstructorParameterDescription(_data.period)), ("proximityNotificationRadius", ConstructorParameterDescription(_data.proximityNotificationRadius))])
            case .inputMediaGeoPoint(let _data):
                return ("inputMediaGeoPoint", [("geoPoint", ConstructorParameterDescription(_data.geoPoint))])
            case .inputMediaInvoice(let _data):
                return ("inputMediaInvoice", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("description", ConstructorParameterDescription(_data.description)), ("photo", ConstructorParameterDescription(_data.photo)), ("invoice", ConstructorParameterDescription(_data.invoice)), ("payload", ConstructorParameterDescription(_data.payload)), ("provider", ConstructorParameterDescription(_data.provider)), ("providerData", ConstructorParameterDescription(_data.providerData)), ("startParam", ConstructorParameterDescription(_data.startParam)), ("extendedMedia", ConstructorParameterDescription(_data.extendedMedia))])
            case .inputMediaPaidMedia(let _data):
                return ("inputMediaPaidMedia", [("flags", ConstructorParameterDescription(_data.flags)), ("starsAmount", ConstructorParameterDescription(_data.starsAmount)), ("extendedMedia", ConstructorParameterDescription(_data.extendedMedia)), ("payload", ConstructorParameterDescription(_data.payload))])
            case .inputMediaPhoto(let _data):
                return ("inputMediaPhoto", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds)), ("video", ConstructorParameterDescription(_data.video))])
            case .inputMediaPhotoExternal(let _data):
                return ("inputMediaPhotoExternal", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds))])
            case .inputMediaPoll(let _data):
                return ("inputMediaPoll", [("flags", ConstructorParameterDescription(_data.flags)), ("poll", ConstructorParameterDescription(_data.poll)), ("correctAnswers", ConstructorParameterDescription(_data.correctAnswers)), ("attachedMedia", ConstructorParameterDescription(_data.attachedMedia)), ("solution", ConstructorParameterDescription(_data.solution)), ("solutionEntities", ConstructorParameterDescription(_data.solutionEntities)), ("solutionMedia", ConstructorParameterDescription(_data.solutionMedia))])
            case .inputMediaStakeDice(let _data):
                return ("inputMediaStakeDice", [("gameHash", ConstructorParameterDescription(_data.gameHash)), ("tonAmount", ConstructorParameterDescription(_data.tonAmount)), ("clientSeed", ConstructorParameterDescription(_data.clientSeed))])
            case .inputMediaStory(let _data):
                return ("inputMediaStory", [("peer", ConstructorParameterDescription(_data.peer)), ("id", ConstructorParameterDescription(_data.id))])
            case .inputMediaTodo(let _data):
                return ("inputMediaTodo", [("todo", ConstructorParameterDescription(_data.todo))])
            case .inputMediaUploadedDocument(let _data):
                return ("inputMediaUploadedDocument", [("flags", ConstructorParameterDescription(_data.flags)), ("file", ConstructorParameterDescription(_data.file)), ("thumb", ConstructorParameterDescription(_data.thumb)), ("mimeType", ConstructorParameterDescription(_data.mimeType)), ("attributes", ConstructorParameterDescription(_data.attributes)), ("stickers", ConstructorParameterDescription(_data.stickers)), ("videoCover", ConstructorParameterDescription(_data.videoCover)), ("videoTimestamp", ConstructorParameterDescription(_data.videoTimestamp)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds))])
            case .inputMediaUploadedPhoto(let _data):
                return ("inputMediaUploadedPhoto", [("flags", ConstructorParameterDescription(_data.flags)), ("file", ConstructorParameterDescription(_data.file)), ("stickers", ConstructorParameterDescription(_data.stickers)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds)), ("video", ConstructorParameterDescription(_data.video))])
            case .inputMediaVenue(let _data):
                return ("inputMediaVenue", [("geoPoint", ConstructorParameterDescription(_data.geoPoint)), ("title", ConstructorParameterDescription(_data.title)), ("address", ConstructorParameterDescription(_data.address)), ("provider", ConstructorParameterDescription(_data.provider)), ("venueId", ConstructorParameterDescription(_data.venueId)), ("venueType", ConstructorParameterDescription(_data.venueType))])
            case .inputMediaWebPage(let _data):
                return ("inputMediaWebPage", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url))])
            }
        }

        public static func parse_inputMediaContact(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaContact(Cons_inputMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, vcard: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDice(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaDice(Cons_inputMediaDice(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDocument(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _3: Api.InputPhoto?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.InputPhoto
                }
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputMedia.inputMediaDocument(Cons_inputMediaDocument(flags: _1!, id: _2!, videoCover: _3, videoTimestamp: _4, ttlSeconds: _5, query: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDocumentExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.InputPhoto?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputPhoto
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputMedia.inputMediaDocumentExternal(Cons_inputMediaDocumentExternal(flags: _1!, url: _2!, ttlSeconds: _3, videoCover: _4, videoTimestamp: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaEmpty(_ reader: BufferReader) -> InputMedia? {
            return Api.InputMedia.inputMediaEmpty
        }
        public static func parse_inputMediaGame(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGame?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGame
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaGame(Cons_inputMediaGame(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGeoLive(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputMedia.inputMediaGeoLive(Cons_inputMediaGeoLive(flags: _1!, geoPoint: _2!, heading: _3, period: _4, proximityNotificationRadius: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGeoPoint(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaGeoPoint(Cons_inputMediaGeoPoint(geoPoint: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaInvoice(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
                }
            }
            var _5: Api.Invoice?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _7 = parseString(reader)
            }
            var _8: Api.DataJSON?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _9: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _9 = parseString(reader)
            }
            var _10: Api.InputMedia?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.InputMedia
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.InputMedia.inputMediaInvoice(Cons_inputMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7, providerData: _8!, startParam: _9, extendedMedia: _10))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPaidMedia(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.InputMedia]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputMedia.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaPaidMedia(Cons_inputMediaPaidMedia(flags: _1!, starsAmount: _2!, extendedMedia: _3!, payload: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPhoto(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.InputDocument?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputDocument
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaPhoto(Cons_inputMediaPhoto(flags: _1!, id: _2!, ttlSeconds: _3, video: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPhotoExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaPhotoExternal(Cons_inputMediaPhotoExternal(flags: _1!, url: _2!, ttlSeconds: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPoll(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Poll?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Poll
            }
            var _3: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _4: Api.InputMedia?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputMedia
                }
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _7: Api.InputMedia?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.InputMedia
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputMedia.inputMediaPoll(Cons_inputMediaPoll(flags: _1!, poll: _2!, correctAnswers: _3, attachedMedia: _4, solution: _5, solutionEntities: _6, solutionMedia: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaStakeDice(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaStakeDice(Cons_inputMediaStakeDice(gameHash: _1!, tonAmount: _2!, clientSeed: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaStory(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMedia.inputMediaStory(Cons_inputMediaStory(peer: _1!, id: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaTodo(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.TodoList?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TodoList
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaTodo(Cons_inputMediaTodo(todo: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaUploadedDocument(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.InputFile
                }
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            var _6: [Api.InputDocument]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
                }
            }
            var _7: Api.InputPhoto?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.InputPhoto
                }
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _9 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputMedia.inputMediaUploadedDocument(Cons_inputMediaUploadedDocument(flags: _1!, file: _2!, thumb: _3, mimeType: _4!, attributes: _5!, stickers: _6, videoCover: _7, videoTimestamp: _8, ttlSeconds: _9))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaUploadedPhoto(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            var _3: [Api.InputDocument]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
                }
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Api.InputDocument?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InputDocument
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputMedia.inputMediaUploadedPhoto(Cons_inputMediaUploadedPhoto(flags: _1!, file: _2!, stickers: _3, ttlSeconds: _4, video: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaVenue(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputMedia.inputMediaVenue(Cons_inputMediaVenue(geoPoint: _1!, title: _2!, address: _3!, provider: _4!, venueId: _5!, venueType: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaWebPage(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMedia.inputMediaWebPage(Cons_inputMediaWebPage(flags: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputMessage: TypeConstructorDescription {
        public class Cons_inputMessageCallbackQuery: TypeConstructorDescription {
            public var id: Int32
            public var queryId: Int64
            public init(id: Int32, queryId: Int64) {
                self.id = id
                self.queryId = queryId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageCallbackQuery", [("id", ConstructorParameterDescription(self.id)), ("queryId", ConstructorParameterDescription(self.queryId))])
            }
        }
        public class Cons_inputMessageID: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageID", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputMessageReplyTo: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageReplyTo", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case inputMessageCallbackQuery(Cons_inputMessageCallbackQuery)
        case inputMessageID(Cons_inputMessageID)
        case inputMessagePinned
        case inputMessageReplyTo(Cons_inputMessageReplyTo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMessageCallbackQuery(let _data):
                if boxed {
                    buffer.appendInt32(-1392895362)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                break
            case .inputMessageID(let _data):
                if boxed {
                    buffer.appendInt32(-1502174430)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .inputMessagePinned:
                if boxed {
                    buffer.appendInt32(-2037963464)
                }
                break
            case .inputMessageReplyTo(let _data):
                if boxed {
                    buffer.appendInt32(-1160215659)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMessageCallbackQuery(let _data):
                return ("inputMessageCallbackQuery", [("id", ConstructorParameterDescription(_data.id)), ("queryId", ConstructorParameterDescription(_data.queryId))])
            case .inputMessageID(let _data):
                return ("inputMessageID", [("id", ConstructorParameterDescription(_data.id))])
            case .inputMessagePinned:
                return ("inputMessagePinned", [])
            case .inputMessageReplyTo(let _data):
                return ("inputMessageReplyTo", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_inputMessageCallbackQuery(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMessage.inputMessageCallbackQuery(Cons_inputMessageCallbackQuery(id: _1!, queryId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessageID(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageID(Cons_inputMessageID(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessagePinned(_ reader: BufferReader) -> InputMessage? {
            return Api.InputMessage.inputMessagePinned
        }
        public static func parse_inputMessageReplyTo(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageReplyTo(Cons_inputMessageReplyTo(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputMessageReadMetric: TypeConstructorDescription {
        public class Cons_inputMessageReadMetric: TypeConstructorDescription {
            public var msgId: Int32
            public var viewId: Int64
            public var timeInViewMs: Int32
            public var activeTimeInViewMs: Int32
            public var heightToViewportRatioPermille: Int32
            public var seenRangeRatioPermille: Int32
            public init(msgId: Int32, viewId: Int64, timeInViewMs: Int32, activeTimeInViewMs: Int32, heightToViewportRatioPermille: Int32, seenRangeRatioPermille: Int32) {
                self.msgId = msgId
                self.viewId = viewId
                self.timeInViewMs = timeInViewMs
                self.activeTimeInViewMs = activeTimeInViewMs
                self.heightToViewportRatioPermille = heightToViewportRatioPermille
                self.seenRangeRatioPermille = seenRangeRatioPermille
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageReadMetric", [("msgId", ConstructorParameterDescription(self.msgId)), ("viewId", ConstructorParameterDescription(self.viewId)), ("timeInViewMs", ConstructorParameterDescription(self.timeInViewMs)), ("activeTimeInViewMs", ConstructorParameterDescription(self.activeTimeInViewMs)), ("heightToViewportRatioPermille", ConstructorParameterDescription(self.heightToViewportRatioPermille)), ("seenRangeRatioPermille", ConstructorParameterDescription(self.seenRangeRatioPermille))])
            }
        }
        case inputMessageReadMetric(Cons_inputMessageReadMetric)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMessageReadMetric(let _data):
                if boxed {
                    buffer.appendInt32(1076577429)
                }
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.viewId, buffer: buffer, boxed: false)
                serializeInt32(_data.timeInViewMs, buffer: buffer, boxed: false)
                serializeInt32(_data.activeTimeInViewMs, buffer: buffer, boxed: false)
                serializeInt32(_data.heightToViewportRatioPermille, buffer: buffer, boxed: false)
                serializeInt32(_data.seenRangeRatioPermille, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMessageReadMetric(let _data):
                return ("inputMessageReadMetric", [("msgId", ConstructorParameterDescription(_data.msgId)), ("viewId", ConstructorParameterDescription(_data.viewId)), ("timeInViewMs", ConstructorParameterDescription(_data.timeInViewMs)), ("activeTimeInViewMs", ConstructorParameterDescription(_data.activeTimeInViewMs)), ("heightToViewportRatioPermille", ConstructorParameterDescription(_data.heightToViewportRatioPermille)), ("seenRangeRatioPermille", ConstructorParameterDescription(_data.seenRangeRatioPermille))])
            }
        }

        public static func parse_inputMessageReadMetric(_ reader: BufferReader) -> InputMessageReadMetric? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputMessageReadMetric.inputMessageReadMetric(Cons_inputMessageReadMetric(msgId: _1!, viewId: _2!, timeInViewMs: _3!, activeTimeInViewMs: _4!, heightToViewportRatioPermille: _5!, seenRangeRatioPermille: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputNotifyPeer: TypeConstructorDescription {
        public class Cons_inputNotifyForumTopic: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var topMsgId: Int32
            public init(peer: Api.InputPeer, topMsgId: Int32) {
                self.peer = peer
                self.topMsgId = topMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputNotifyForumTopic", [("peer", ConstructorParameterDescription(self.peer)), ("topMsgId", ConstructorParameterDescription(self.topMsgId))])
            }
        }
        public class Cons_inputNotifyPeer: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputNotifyPeer", [("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyForumTopic(Cons_inputNotifyForumTopic)
        case inputNotifyPeer(Cons_inputNotifyPeer)
        case inputNotifyUsers

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputNotifyBroadcasts:
                if boxed {
                    buffer.appendInt32(-1311015810)
                }
                break
            case .inputNotifyChats:
                if boxed {
                    buffer.appendInt32(1251338318)
                }
                break
            case .inputNotifyForumTopic(let _data):
                if boxed {
                    buffer.appendInt32(1548122514)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMsgId, buffer: buffer, boxed: false)
                break
            case .inputNotifyPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1195615476)
                }
                _data.peer.serialize(buffer, true)
                break
            case .inputNotifyUsers:
                if boxed {
                    buffer.appendInt32(423314455)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputNotifyBroadcasts:
                return ("inputNotifyBroadcasts", [])
            case .inputNotifyChats:
                return ("inputNotifyChats", [])
            case .inputNotifyForumTopic(let _data):
                return ("inputNotifyForumTopic", [("peer", ConstructorParameterDescription(_data.peer)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId))])
            case .inputNotifyPeer(let _data):
                return ("inputNotifyPeer", [("peer", ConstructorParameterDescription(_data.peer))])
            case .inputNotifyUsers:
                return ("inputNotifyUsers", [])
            }
        }

        public static func parse_inputNotifyBroadcasts(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyBroadcasts
        }
        public static func parse_inputNotifyChats(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyChats
        }
        public static func parse_inputNotifyForumTopic(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputNotifyPeer.inputNotifyForumTopic(Cons_inputNotifyForumTopic(peer: _1!, topMsgId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputNotifyPeer(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputNotifyPeer.inputNotifyPeer(Cons_inputNotifyPeer(peer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputNotifyUsers(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyUsers
        }
    }
}
public extension Api {
    enum InputPasskeyCredential: TypeConstructorDescription {
        public class Cons_inputPasskeyCredentialFirebasePNV: TypeConstructorDescription {
            public var pnvToken: String
            public init(pnvToken: String) {
                self.pnvToken = pnvToken
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPasskeyCredentialFirebasePNV", [("pnvToken", ConstructorParameterDescription(self.pnvToken))])
            }
        }
        public class Cons_inputPasskeyCredentialPublicKey: TypeConstructorDescription {
            public var id: String
            public var rawId: String
            public var response: Api.InputPasskeyResponse
            public init(id: String, rawId: String, response: Api.InputPasskeyResponse) {
                self.id = id
                self.rawId = rawId
                self.response = response
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPasskeyCredentialPublicKey", [("id", ConstructorParameterDescription(self.id)), ("rawId", ConstructorParameterDescription(self.rawId)), ("response", ConstructorParameterDescription(self.response))])
            }
        }
        case inputPasskeyCredentialFirebasePNV(Cons_inputPasskeyCredentialFirebasePNV)
        case inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPasskeyCredentialFirebasePNV(let _data):
                if boxed {
                    buffer.appendInt32(1528613672)
                }
                serializeString(_data.pnvToken, buffer: buffer, boxed: false)
                break
            case .inputPasskeyCredentialPublicKey(let _data):
                if boxed {
                    buffer.appendInt32(1009235855)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.rawId, buffer: buffer, boxed: false)
                _data.response.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPasskeyCredentialFirebasePNV(let _data):
                return ("inputPasskeyCredentialFirebasePNV", [("pnvToken", ConstructorParameterDescription(_data.pnvToken))])
            case .inputPasskeyCredentialPublicKey(let _data):
                return ("inputPasskeyCredentialPublicKey", [("id", ConstructorParameterDescription(_data.id)), ("rawId", ConstructorParameterDescription(_data.rawId)), ("response", ConstructorParameterDescription(_data.response))])
            }
        }

        public static func parse_inputPasskeyCredentialFirebasePNV(_ reader: BufferReader) -> InputPasskeyCredential? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPasskeyCredential.inputPasskeyCredentialFirebasePNV(Cons_inputPasskeyCredentialFirebasePNV(pnvToken: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPasskeyCredentialPublicKey(_ reader: BufferReader) -> InputPasskeyCredential? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPasskeyResponse?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPasskeyResponse
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputPasskeyCredential.inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey(id: _1!, rawId: _2!, response: _3!))
            }
            else {
                return nil
            }
        }
    }
}
