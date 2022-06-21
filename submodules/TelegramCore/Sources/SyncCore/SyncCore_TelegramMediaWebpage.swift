import Postbox

private enum TelegramMediaWebpageAttributeTypes: Int32 {
    case unsupported
    case theme
}

public enum TelegramMediaWebpageAttribute: PostboxCoding, Equatable {
    case unsupported
    case theme(TelegraMediaWebpageThemeAttribute)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case TelegramMediaWebpageAttributeTypes.theme.rawValue:
                self = .theme(decoder.decodeObjectForKey("a", decoder: { TelegraMediaWebpageThemeAttribute(decoder: $0) }) as! TelegraMediaWebpageThemeAttribute)
            default:
                self = .unsupported
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .unsupported:
                encoder.encodeInt32(TelegramMediaWebpageAttributeTypes.unsupported.rawValue, forKey: "r")
            case let .theme(attribute):
                encoder.encodeInt32(TelegramMediaWebpageAttributeTypes.theme.rawValue, forKey: "r")
                encoder.encodeObject(attribute, forKey: "a")
        }
    }
}

public final class TelegraMediaWebpageThemeAttribute: PostboxCoding, Equatable {
    public static func == (lhs: TelegraMediaWebpageThemeAttribute, rhs: TelegraMediaWebpageThemeAttribute) -> Bool {
        if lhs.settings != rhs.settings {
            return false
        }
        if lhs.files.count != rhs.files.count {
            return false
        } else {
            for i in 0 ..< lhs.files.count {
                if !lhs.files[i].isEqual(to: rhs.files[i]) {
                    return false
                }
            }
        }
        return true
    }
    
    public let files: [TelegramMediaFile]
    public let settings: TelegramThemeSettings?
    
    public init(files: [TelegramMediaFile], settings: TelegramThemeSettings?) {
        self.files = files
        self.settings = settings
    }
    
    public init(decoder: PostboxDecoder) {
        self.files = decoder.decodeObjectArrayForKey("files")
        self.settings = decoder.decode(TelegramThemeSettings.self, forKey: "settings")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.files, forKey: "files")
        if let settings = self.settings {
            encoder.encode(settings, forKey: "settings")
        } else {
            encoder.encodeNil(forKey: "settings")
        }
    }
}

public final class TelegramMediaWebpageLoadedContent: PostboxCoding, Equatable {
    public let url: String
    public let displayUrl: String
    public let hash: Int32
    public let type: String?
    public let websiteName: String?
    public let title: String?
    public let text: String?
    public let embedUrl: String?
    public let embedType: String?
    public let embedSize: PixelDimensions?
    public let duration: Int?
    public let author: String?
    
    public let image: TelegramMediaImage?
    public let file: TelegramMediaFile?
    public let attributes: [TelegramMediaWebpageAttribute]
    public let instantPage: InstantPage?
    
    public init(url: String, displayUrl: String, hash: Int32, type: String?, websiteName: String?, title: String?, text: String?, embedUrl: String?, embedType: String?, embedSize: PixelDimensions?, duration: Int?, author: String?, image: TelegramMediaImage?, file: TelegramMediaFile?, attributes: [TelegramMediaWebpageAttribute], instantPage: InstantPage?) {
        self.url = url
        self.displayUrl = displayUrl
        self.hash = hash
        self.type = type
        self.websiteName = websiteName
        self.title = title
        self.text = text
        self.embedUrl = embedUrl
        self.embedType = embedType
        self.embedSize = embedSize
        self.duration = duration
        self.author = author
        self.image = image
        self.file = file
        self.attributes = attributes
        self.instantPage = instantPage
    }
    
    public init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
        self.displayUrl = decoder.decodeStringForKey("d", orElse: "")
        self.hash = decoder.decodeInt32ForKey("ha", orElse: 0)
        self.type = decoder.decodeOptionalStringForKey("ty")
        self.websiteName = decoder.decodeOptionalStringForKey("ws")
        self.title = decoder.decodeOptionalStringForKey("ti")
        self.text = decoder.decodeOptionalStringForKey("tx")
        self.embedUrl = decoder.decodeOptionalStringForKey("eu")
        self.embedType = decoder.decodeOptionalStringForKey("et")
        if let embedSizeWidth = decoder.decodeOptionalInt32ForKey("esw"), let embedSizeHeight = decoder.decodeOptionalInt32ForKey("esh") {
            self.embedSize = PixelDimensions(width: embedSizeWidth, height: embedSizeHeight)
        } else {
            self.embedSize = nil
        }
        if let duration = decoder.decodeOptionalInt32ForKey("du") {
            self.duration = Int(duration)
        } else {
            self.duration = nil
        }
        self.author = decoder.decodeOptionalStringForKey("au")
        
        if let image = decoder.decodeObjectForKey("im") as? TelegramMediaImage {
            self.image = image
        } else {
            self.image = nil
        }
        
        if let file = decoder.decodeObjectForKey("fi") as? TelegramMediaFile {
            self.file = file
        } else {
            self.file = nil
        }
        
        var effectiveAttributes: [TelegramMediaWebpageAttribute] = []
        if let attributes = decoder.decodeObjectArrayWithDecoderForKey("attr") as [TelegramMediaWebpageAttribute]? {
            effectiveAttributes.append(contentsOf: attributes)
        }
        if let legacyFiles = decoder.decodeOptionalObjectArrayWithDecoderForKey("fis") as [TelegramMediaFile]? {
            effectiveAttributes.append(.theme(TelegraMediaWebpageThemeAttribute(files: legacyFiles, settings: nil)))
        }
        self.attributes = effectiveAttributes
        
        if let instantPage = decoder.decodeObjectForKey("ip", decoder: { InstantPage(decoder: $0) }) as? InstantPage {
            self.instantPage = instantPage
        } else {
            self.instantPage = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
        encoder.encodeString(self.displayUrl, forKey: "d")
        encoder.encodeInt32(self.hash, forKey: "ha")
        if let type = self.type {
            encoder.encodeString(type, forKey: "ty")
        } else {
            encoder.encodeNil(forKey: "ty")
        }
        if let websiteName = self.websiteName {
            encoder.encodeString(websiteName, forKey: "ws")
        } else {
            encoder.encodeNil(forKey: "ws")
        }
        if let title = self.title {
            encoder.encodeString(title, forKey: "ti")
        } else {
            encoder.encodeNil(forKey: "ti")
        }
        if let text = self.text {
            encoder.encodeString(text, forKey: "tx")
        } else {
            encoder.encodeNil(forKey: "tx")
        }
        if let embedUrl = self.embedUrl {
            encoder.encodeString(embedUrl, forKey: "eu")
        } else {
            encoder.encodeNil(forKey: "eu")
        }
        if let embedType = self.embedType {
            encoder.encodeString(embedType, forKey: "et")
        } else {
            encoder.encodeNil(forKey: "et")
        }
        if let embedSize = self.embedSize {
            encoder.encodeInt32(Int32(embedSize.width), forKey: "esw")
            encoder.encodeInt32(Int32(embedSize.height), forKey: "esh")
        } else {
            encoder.encodeNil(forKey: "esw")
            encoder.encodeNil(forKey: "esh")
        }
        if let duration = self.duration {
            encoder.encodeInt32(Int32(duration), forKey: "du")
        } else {
            encoder.encodeNil(forKey: "du")
        }
        if let author = self.author {
            encoder.encodeString(author, forKey: "au")
        } else {
            encoder.encodeNil(forKey: "au")
        }
        if let image = self.image {
            encoder.encodeObject(image, forKey: "im")
        } else {
            encoder.encodeNil(forKey: "im")
        }
        if let file = self.file {
            encoder.encodeObject(file, forKey: "fi")
        } else {
            encoder.encodeNil(forKey: "fi")
        }
        
        encoder.encodeObjectArray(self.attributes, forKey: "attr")
        
        if let instantPage = self.instantPage {
            encoder.encodeObject(instantPage, forKey: "ip")
        } else {
            encoder.encodeNil(forKey: "ip")
        }
    }
}

public func ==(lhs: TelegramMediaWebpageLoadedContent, rhs: TelegramMediaWebpageLoadedContent) -> Bool {
    if lhs.url != rhs.url
    || lhs.displayUrl != rhs.displayUrl
    || lhs.hash != rhs.hash
    || lhs.type != rhs.type
    || lhs.websiteName != rhs.websiteName
    || lhs.title != rhs.title
    || lhs.text != rhs.text
    || lhs.embedUrl != rhs.embedUrl
    || lhs.embedType != rhs.embedType
    || lhs.embedSize != rhs.embedSize
    || lhs.duration != rhs.duration
    || lhs.author != rhs.author {
        return false
    }
    
    if let lhsImage = lhs.image, let rhsImage = rhs.image {
        if !lhsImage.isEqual(to: rhsImage) {
            return false
        }
    } else if (lhs.image == nil) != (rhs.image == nil) {
        return false
    }
    
    if let lhsFile = lhs.file, let rhsFile = rhs.file {
        if !lhsFile.isEqual(to: rhsFile) {
            return false
        }
    } else if (lhs.file == nil) != (rhs.file == nil) {
        return false
    }
    
    if lhs.attributes.count != rhs.attributes.count {
        return false
    } else {
        for i in 0 ..< lhs.attributes.count {
            if lhs.attributes[i] != rhs.attributes[i] {
                return false
            }
        }
    }
    
    if lhs.instantPage != rhs.instantPage {
        return false
    }
    
    return true
}

public enum TelegramMediaWebpageContent {
    case Pending(Int32, String?)
    case Loaded(TelegramMediaWebpageLoadedContent)
}

public final class TelegramMediaWebpage: Media, Equatable {
    public var id: MediaId? {
        return self.webpageId
    }
    public let peerIds: [PeerId] = []
    
    public let webpageId: MediaId
    public let content: TelegramMediaWebpageContent
    
    public init(webpageId: MediaId, content: TelegramMediaWebpageContent) {
        self.webpageId = webpageId
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.webpageId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        
        if decoder.decodeInt32ForKey("ct", orElse: 0) == 0 {
            self.content = .Pending(decoder.decodeInt32ForKey("pendingDate", orElse: 0), decoder.decodeOptionalStringForKey("pendingUrl"))
        } else {
            self.content = .Loaded(TelegramMediaWebpageLoadedContent(decoder: decoder))
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.webpageId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        
        switch self.content {
            case let .Pending(date, url):
                encoder.encodeInt32(0, forKey: "ct")
                encoder.encodeInt32(date, forKey: "pendingDate")
                if let url = url {
                    encoder.encodeString(url, forKey: "pendingUrl")
                } else {
                    encoder.encodeNil(forKey: "pendingUrl")
                }
            case let .Loaded(loadedContent):
                encoder.encodeInt32(1, forKey: "ct")
                loadedContent.encode(encoder)
        }
    }
    
    public func isLikelyToBeUpdated() -> Bool {
        return true
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaWebpage, self.webpageId == other.webpageId {
            return self == other
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public static func ==(lhs: TelegramMediaWebpage, rhs: TelegramMediaWebpage) -> Bool {
        if lhs.webpageId != rhs.webpageId {
            return false
        }
        
        switch lhs.content {
            case let .Pending(lhsDate, lhsUrl):
                switch rhs.content {
                    case let .Pending(rhsDate, rhsUrl):
                        if lhsDate == rhsDate, lhsUrl == rhsUrl {
                            return true
                        } else {
                            return false
                        }
                    default:
                        return false
                }
            case let .Loaded(lhsContent):
                switch rhs.content {
                    case let .Loaded(rhsContent) where lhsContent == rhsContent:
                        return true
                    default:
                        return false
                }
        }
    }
}
