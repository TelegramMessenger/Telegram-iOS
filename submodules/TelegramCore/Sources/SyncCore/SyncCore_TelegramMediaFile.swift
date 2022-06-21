    import Foundation
import Postbox

private let typeFileName: Int32 = 0
private let typeSticker: Int32 = 1
private let typeImageSize: Int32 = 2
private let typeAnimated: Int32 = 3
private let typeVideo: Int32 = 4
private let typeAudio: Int32 = 5
private let typeHasLinkedStickers: Int32 = 6
private let typeHintFileIsLarge: Int32 = 7
private let typeHintIsValidated: Int32 = 8

public enum StickerPackReference: PostboxCoding, Hashable, Equatable {
    case id(id: Int64, accessHash: Int64)
    case name(String)
    case animatedEmoji
    case dice(String)
    case animatedEmojiAnimations
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .id(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case 1:
                self = .name(decoder.decodeStringForKey("n", orElse: ""))
            case 2:
                self = .animatedEmoji
            case 3:
                self = .dice(decoder.decodeStringForKey("e", orElse: "🎲"))
            case 4:
                self = .animatedEmojiAnimations
            default:
                self = .name("")
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .id(id, accessHash):
                encoder.encodeInt32(0, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case let .name(name):
                encoder.encodeInt32(1, forKey: "r")
                encoder.encodeString(name, forKey: "n")
            case .animatedEmoji:
                encoder.encodeInt32(2, forKey: "r")
            case let .dice(emoji):
                encoder.encodeInt32(3, forKey: "r")
                encoder.encodeString(emoji, forKey: "e")
            case .animatedEmojiAnimations:
                encoder.encodeInt32(4, forKey: "r")
        }
    }
    
    public static func ==(lhs: StickerPackReference, rhs: StickerPackReference) -> Bool {
        switch lhs {
            case let .id(id, accessHash):
                if case .id(id, accessHash) = rhs {
                    return true
                } else {
                    return false
                }
            case let .name(name):
                if case .name(name) = rhs {
                    return true
                } else {
                    return false
                }
            case .animatedEmoji:
                if case .animatedEmoji = rhs {
                    return true
                } else {
                    return false
                }
            case let .dice(emoji):
                if case .dice(emoji) = rhs {
                    return true
                } else {
                    return false
                }
            case .animatedEmojiAnimations:
                if case .animatedEmojiAnimations = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct TelegramMediaVideoFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let instantRoundVideo = TelegramMediaVideoFlags(rawValue: 1 << 0)
    public static let supportsStreaming = TelegramMediaVideoFlags(rawValue: 1 << 1)
}

public struct StickerMaskCoords: PostboxCoding {
    public let n: Int32
    public let x: Double
    public let y: Double
    public let zoom: Double
    
    public init(n: Int32, x: Double, y: Double, zoom: Double) {
        self.n = n
        self.x = x
        self.y = y
        self.zoom = zoom
    }
    
    public init(decoder: PostboxDecoder) {
        self.n = decoder.decodeInt32ForKey("n", orElse: 0)
        self.x = decoder.decodeDoubleForKey("x", orElse: 0.0)
        self.y = decoder.decodeDoubleForKey("y", orElse: 0.0)
        self.zoom = decoder.decodeDoubleForKey("z", orElse: 0.0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.n, forKey: "n")
        encoder.encodeDouble(self.x, forKey: "x")
        encoder.encodeDouble(self.y, forKey: "y")
        encoder.encodeDouble(self.zoom, forKey: "z")
    }
}

public enum TelegramMediaFileAttribute: PostboxCoding {
    case FileName(fileName: String)
    case Sticker(displayText: String, packReference: StickerPackReference?, maskData: StickerMaskCoords?)
    case ImageSize(size: PixelDimensions)
    case Animated
    case Video(duration: Int, size: PixelDimensions, flags: TelegramMediaVideoFlags)
    case Audio(isVoice: Bool, duration: Int, title: String?, performer: String?, waveform: Data?)
    case HasLinkedStickers
    case hintFileIsLarge
    case hintIsValidated
    
    public init(decoder: PostboxDecoder) {
        let type: Int32 = decoder.decodeInt32ForKey("t", orElse: 0)
        switch type {
            case typeFileName:
                self = .FileName(fileName: decoder.decodeStringForKey("fn", orElse: ""))
            case typeSticker:
                self = .Sticker(displayText: decoder.decodeStringForKey("dt", orElse: ""), packReference: decoder.decodeObjectForKey("pr", decoder: { StickerPackReference(decoder: $0) }) as? StickerPackReference, maskData: decoder.decodeObjectForKey("mc", decoder: { StickerMaskCoords(decoder: $0) }) as? StickerMaskCoords)
            case typeImageSize:
                self = .ImageSize(size: PixelDimensions(width: decoder.decodeInt32ForKey("w", orElse: 0), height: decoder.decodeInt32ForKey("h", orElse: 0)))
            case typeAnimated:
                self = .Animated
            case typeVideo:
                self = .Video(duration: Int(decoder.decodeInt32ForKey("du", orElse: 0)), size: PixelDimensions(width: decoder.decodeInt32ForKey("w", orElse: 0), height: decoder.decodeInt32ForKey("h", orElse: 0)), flags: TelegramMediaVideoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0)))
            case typeAudio:
                let waveformBuffer = decoder.decodeBytesForKeyNoCopy("wf")
                var waveform: Data?
                if let waveformBuffer = waveformBuffer {
                    waveform = waveformBuffer.makeData()
                }
                self = .Audio(isVoice: decoder.decodeInt32ForKey("iv", orElse: 0) != 0, duration: Int(decoder.decodeInt32ForKey("du", orElse: 0)), title: decoder.decodeOptionalStringForKey("ti"), performer: decoder.decodeOptionalStringForKey("pe"), waveform: waveform)
            case typeHasLinkedStickers:
                self = .HasLinkedStickers
            case typeHintFileIsLarge:
                self = .hintFileIsLarge
            case typeHintIsValidated:
                self = .hintIsValidated
            default:
                preconditionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .FileName(fileName):
                encoder.encodeInt32(typeFileName, forKey: "t")
                encoder.encodeString(fileName, forKey: "fn")
            case let .Sticker(displayText, packReference, maskCoords):
                encoder.encodeInt32(typeSticker, forKey: "t")
                encoder.encodeString(displayText, forKey: "dt")
                if let packReference = packReference {
                    encoder.encodeObject(packReference, forKey: "pr")
                } else {
                    encoder.encodeNil(forKey: "pr")
                }
                if let maskCoords = maskCoords {
                    encoder.encodeObject(maskCoords, forKey: "mc")
                } else {
                    encoder.encodeNil(forKey: "mc")
                }
            case let .ImageSize(size):
                encoder.encodeInt32(typeImageSize, forKey: "t")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
            case .Animated:
                encoder.encodeInt32(typeAnimated, forKey: "t")
            case let .Video(duration, size, flags):
                encoder.encodeInt32(typeVideo, forKey: "t")
                encoder.encodeInt32(Int32(duration), forKey: "du")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
                encoder.encodeInt32(flags.rawValue, forKey: "f")
            case let .Audio(isVoice, duration, title, performer, waveform):
                encoder.encodeInt32(typeAudio, forKey: "t")
                encoder.encodeInt32(isVoice ? 1 : 0, forKey: "iv")
                encoder.encodeInt32(Int32(duration), forKey: "du")
                if let title = title {
                    encoder.encodeString(title, forKey: "ti")
                }
                if let performer = performer {
                    encoder.encodeString(performer, forKey: "pe")
                }
                if let waveform = waveform {
                    encoder.encodeBytes(MemoryBuffer(data: waveform), forKey: "wf")
                }
            case .HasLinkedStickers:
                encoder.encodeInt32(typeHasLinkedStickers, forKey: "t")
            case .hintFileIsLarge:
                encoder.encodeInt32(typeHintFileIsLarge, forKey: "t")
            case .hintIsValidated:
                encoder.encodeInt32(typeHintIsValidated, forKey: "t")
        }
    }
}

public enum TelegramMediaFileReference: PostboxCoding, Equatable {
    case cloud(fileId: Int64, accessHash: Int64, fileReference: Data?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .cloud(fileId: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeBytesForKey("fr")?.makeData())
            default:
                self = .cloud(fileId: 0, accessHash: 0, fileReference: nil)
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .cloud(imageId, accessHash, fileReference):
                encoder.encodeInt32(0, forKey: "_v")
                encoder.encodeInt64(imageId, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
        }
    }
}

public enum TelegramMediaFileDecodingError: Error {
    case generic
}

public final class TelegramMediaFile: Media, Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    public final class VideoThumbnail: Equatable, PostboxCoding {
        public let dimensions: PixelDimensions
        public let resource: TelegramMediaResource
        
        public init(dimensions: PixelDimensions, resource: TelegramMediaResource) {
            self.dimensions = dimensions
            self.resource = resource
        }
        
        public init(decoder: PostboxDecoder) {
            self.dimensions = PixelDimensions(width: decoder.decodeInt32ForKey("w", orElse: 0), height: decoder.decodeInt32ForKey("h", orElse: 0))
            self.resource = decoder.decodeObjectForKey("r") as! TelegramMediaResource
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.dimensions.width, forKey: "w")
            encoder.encodeInt32(self.dimensions.height, forKey: "h")
            encoder.encodeObject(self.resource, forKey: "r")
        }
        
        public static func ==(lhs: VideoThumbnail, rhs: VideoThumbnail) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.dimensions != rhs.dimensions {
                return false
            }
            if !lhs.resource.isEqual(to: rhs.resource) {
                return false
            }
            return true
        }
    }
    
    public let fileId: MediaId
    public let partialReference: PartialMediaReference?
    public let resource: TelegramMediaResource
    public let previewRepresentations: [TelegramMediaImageRepresentation]
    public let videoThumbnails: [TelegramMediaFile.VideoThumbnail]
    public let immediateThumbnailData: Data?
    public let mimeType: String
    public let size: Int?
    public let attributes: [TelegramMediaFileAttribute]
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return self.fileId
    }
    
    public var indexableText: String? {
        var result = ""
        for attribute in self.attributes {
            if case let .FileName(fileName) = attribute {
                if !result.isEmpty {
                    result.append(" ")
                }
                result.append(fileName)
            }
        }
        return result.isEmpty ? nil : result
    }
    
    public init(fileId: MediaId, partialReference: PartialMediaReference?, resource: TelegramMediaResource, previewRepresentations: [TelegramMediaImageRepresentation], videoThumbnails: [TelegramMediaFile.VideoThumbnail], immediateThumbnailData: Data?, mimeType: String, size: Int?, attributes: [TelegramMediaFileAttribute]) {
        self.fileId = fileId
        self.partialReference = partialReference
        self.resource = resource
        self.previewRepresentations = previewRepresentations
        self.videoThumbnails = videoThumbnails
        self.immediateThumbnailData = immediateThumbnailData
        self.mimeType = mimeType
        self.size = size
        self.attributes = attributes
    }
    
    public init(decoder: PostboxDecoder) {
        self.fileId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        self.partialReference = decoder.decodeAnyObjectForKey("prf", decoder: { PartialMediaReference(decoder: $0) }) as? PartialMediaReference
        self.resource = decoder.decodeObjectForKey("r") as? TelegramMediaResource ?? EmptyMediaResource()
        self.previewRepresentations = decoder.decodeObjectArrayForKey("pr")
        self.videoThumbnails = decoder.decodeObjectArrayForKey("vr")
        self.immediateThumbnailData = decoder.decodeDataForKey("itd")
        self.mimeType = decoder.decodeStringForKey("mt", orElse: "")
        if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int(size)
        } else {
            self.size = nil
        }
        self.attributes = decoder.decodeObjectArrayForKey("at")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.fileId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        if let partialReference = self.partialReference {
            encoder.encodeObjectWithEncoder(partialReference, encoder: partialReference.encode, forKey: "prf")
        } else {
            encoder.encodeNil(forKey: "prf")
        }
        encoder.encodeObject(self.resource, forKey: "r")
        encoder.encodeObjectArray(self.previewRepresentations, forKey: "pr")
        encoder.encodeObjectArray(self.videoThumbnails, forKey: "vr")
        if let immediateThumbnailData = self.immediateThumbnailData {
            encoder.encodeData(immediateThumbnailData, forKey: "itd")
        } else {
            encoder.encodeNil(forKey: "itd")
        }
        encoder.encodeString(self.mimeType, forKey: "mt")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeObjectArray(self.attributes, forKey: "at")
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        let postboxDecoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        guard let object = postboxDecoder.decodeRootObject() as? TelegramMediaFile else {
            throw TelegramMediaFileDecodingError.generic
        }
        self.fileId = object.fileId
        self.partialReference = object.partialReference
        self.resource = object.resource
        self.previewRepresentations = object.previewRepresentations
        self.videoThumbnails = object.videoThumbnails
        self.immediateThumbnailData = object.immediateThumbnailData
        self.mimeType = object.mimeType
        self.size = object.size
        self.attributes = object.attributes
    }
    
    public func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        postboxEncoder.encodeRootObject(self)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postboxEncoder.makeData(), forKey: .data)
    }
    
    public var fileName: String? {
        get {
            for attribute in self.attributes {
                switch attribute {
                    case let .FileName(fileName):
                        return fileName
                    case _:
                        break
                }
            }
            return nil
        }
    }
    
    public var isSticker: Bool {
        for attribute in self.attributes {
            if case .Sticker = attribute {
                return true
            }
        }
        return false
    }
    
    public var isStaticSticker: Bool {
        for attribute in self.attributes {
            if case .Sticker = attribute {
                if let s = self.size, s < 300 * 1024 {
                    return !isAnimatedSticker
                } else if self.size == nil {
                    return !isAnimatedSticker
                }
            }
        }
        return false
    }
    
    public var isVideo: Bool {
        for attribute in self.attributes {
            if case .Video = attribute {
                return true
            }
        }
        return false
    }
    
    public var isInstantVideo: Bool {
        for attribute in self.attributes {
            if case .Video(_, _, let flags) = attribute {
                return flags.contains(.instantRoundVideo)
            }
        }
        return false
    }
    
    public var isAnimated: Bool {
        for attribute in self.attributes {
            if case .Animated = attribute {
                return true
            }
        }
        return false
    }
    
    public var isAnimatedSticker: Bool {
        if let _ = self.fileName, self.mimeType == "application/x-tgsticker" {
            return true
        }
        return false
    }
    
    public var isVideoSticker: Bool {
        if self.mimeType == "video/webm" {
            var hasSticker = false
            for attribute in self.attributes {
                if case .Sticker = attribute {
                    hasSticker = true
                    break
                }
            }
            return hasSticker
        }
        return false
    }
    
    public var hasLinkedStickers: Bool {
        for attribute in self.attributes {
            if case .HasLinkedStickers = attribute {
                return true
            }
        }
        return false
    }
    
    public var isMusic: Bool {
        for attribute in self.attributes {
            if case .Audio(false, _, _, _, _) = attribute {
                return true
            }
        }
        return false
    }
    
    public var isVoice: Bool {
        for attribute in self.attributes {
            if case .Audio(true, _, _, _, _) = attribute {
                return true
            }
        }
        return false
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaFile else {
            return false
        }
        
        if self.fileId != other.fileId {
            return false
        }
        
        if self.partialReference != other.partialReference {
            return false
        }
        
        if !self.resource.isEqual(to: other.resource) {
            return false
        }
        
        if self.previewRepresentations != other.previewRepresentations {
            return false
        }
        
        if self.immediateThumbnailData != other.immediateThumbnailData {
            return false
        }
        
        if self.size != other.size {
            return false
        }
        
        if self.mimeType != other.mimeType {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaFile else {
            return false
        }
        
        if self.fileId != other.fileId {
            return false
        }
        
        if self.partialReference != other.partialReference {
            return false
        }
        
        if self.resource.id != other.resource.id {
            return false
        }
        
        if self.previewRepresentations.count != other.previewRepresentations.count {
            return false
        }
        
        for i in 0 ..< self.previewRepresentations.count {
            if !self.previewRepresentations[i].isSemanticallyEqual(to: other.previewRepresentations[i]) {
                return false
            }
        }
        
        if self.videoThumbnails.count != other.videoThumbnails.count {
            return false
        }
        
        if self.immediateThumbnailData != other.immediateThumbnailData {
            return false
        }
        
        if self.size != other.size {
            return false
        }
        
        if self.mimeType != other.mimeType {
            return false
        }
        
        return true
    }
    
    public func withUpdatedPartialReference(_ partialReference: PartialMediaReference?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }

    public func withUpdatedResource(_ resource: TelegramMediaResource) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }
    
    public func withUpdatedSize(_ size: Int?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: size, attributes: self.attributes)
    }
    
    public func withUpdatedPreviewRepresentations(_ previewRepresentations: [TelegramMediaImageRepresentation]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }
    
    public func withUpdatedAttributes(_ attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: attributes)
    }
}

public func ==(lhs: TelegramMediaFile, rhs: TelegramMediaFile) -> Bool {
    return lhs.isEqual(to: rhs)
}
