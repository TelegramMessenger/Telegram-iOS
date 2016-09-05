import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private let typeFileName: Int32 = 0
private let typeSticker: Int32 = 1
private let typeImageSize: Int32 = 2
private let typeAnimated: Int32 = 3
private let typeVideo: Int32 = 4
private let typeAudio: Int32 = 5

public enum TelegramMediaFileAttribute: Coding {
    case FileName(fileName: String)
    case Sticker(displayText: String)
    case ImageSize(size: CGSize)
    case Animated
    case Video(duration: Int, size: CGSize)
    case Audio(isVoice: Bool, duration: Int, title: String?, performer: String?, waveform: MemoryBuffer?)
    case Unknown
    
    public init(decoder: Decoder) {
        let type: Int32 = decoder.decodeInt32ForKey("t")
        switch type {
            case typeFileName:
                self = .FileName(fileName: decoder.decodeStringForKey("fn"))
            case typeSticker:
                self = .Sticker(displayText: decoder.decodeStringForKey("dt"))
            case typeImageSize:
                self = .ImageSize(size: CGSize(width: CGFloat(decoder.decodeInt32ForKey("w")), height: CGFloat(decoder.decodeInt32ForKey("h"))))
            case typeAnimated:
                self = .Animated
            case typeVideo:
                self = .Video(duration: Int(decoder.decodeInt32ForKey("du")), size: CGSize(width: CGFloat(decoder.decodeInt32ForKey("w")), height: CGFloat(decoder.decodeInt32ForKey("h"))))
            case typeAudio:
                let waveformBuffer = decoder.decodeBytesForKeyNoCopy("wf")
                var waveform: MemoryBuffer?
                if let waveformBuffer = waveformBuffer {
                    waveform = MemoryBuffer(copyOf: waveformBuffer)
                }
                self = .Audio(isVoice: decoder.decodeInt32ForKey("iv") != 0, duration: Int(decoder.decodeInt32ForKey("du")), title: decoder.decodeStringForKey("ti"), performer: decoder.decodeStringForKey("pe"), waveform: waveform)
            default:
                self = .Unknown
        }
    }
    
    public func encode(_ encoder: Encoder) {
        switch self {
            case let .FileName(fileName):
                encoder.encodeInt32(typeFileName, forKey: "t")
                encoder.encodeString(fileName, forKey: "fn")
            case let .Sticker(displayText):
                encoder.encodeInt32(typeSticker, forKey: "t")
                encoder.encodeString(displayText, forKey: "dt")
            case let .ImageSize(size):
                encoder.encodeInt32(typeImageSize, forKey: "t")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
            case .Animated:
                encoder.encodeInt32(typeAnimated, forKey: "t")
            case let .Video(duration, size):
                encoder.encodeInt32(typeVideo, forKey: "t")
                encoder.encodeInt32(Int32(duration), forKey: "du")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
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
                    encoder.encodeBytes(waveform, forKey: "wf")
                }
            case .Unknown:
                break
        }
    }
}

public final class TelegramMediaFile: Media, Equatable {
    public let fileId: MediaId
    public let location: TelegramMediaLocation
    public let previewRepresentations: [TelegramMediaImageRepresentation]
    public let mimeType: String
    public let size: Int
    public let attributes: [TelegramMediaFileAttribute]
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return self.fileId
    }
    
    public init(fileId: MediaId, location: TelegramMediaLocation, previewRepresentations: [TelegramMediaImageRepresentation], mimeType: String, size: Int, attributes: [TelegramMediaFileAttribute]) {
        self.fileId = fileId
        self.location = location
        self.previewRepresentations = previewRepresentations
        self.mimeType = mimeType
        self.size = size
        self.attributes = attributes
    }
    
    public init(decoder: Decoder) {
        self.fileId = MediaId(decoder.decodeBytesForKeyNoCopy("i"))
        self.location = decoder.decodeObjectForKey("l") as! TelegramMediaLocation
        self.previewRepresentations = decoder.decodeObjectArrayForKey("pr")
        self.mimeType = decoder.decodeStringForKey("mt")
        self.size = Int(decoder.decodeInt32ForKey("s"))
        self.attributes = decoder.decodeObjectArrayForKey("at")
    }
    
    public func encode(_ encoder: Encoder) {
        let buffer = WriteBuffer()
        self.fileId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeObject(self.location, forKey: "l")
        encoder.encodeObjectArray(self.previewRepresentations, forKey: "pr")
        encoder.encodeString(self.mimeType, forKey: "mt")
        encoder.encodeInt32(Int32(self.size), forKey: "s")
        encoder.encodeObjectArray(self.attributes, forKey: "at")
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
    
    public var isVideo: Bool {
        for attribute in self.attributes {
            if case .Video = attribute {
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
    
    public var dimensions: CGSize? {
        for attribute in self.attributes {
            switch attribute {
                case let .Video(_, size):
                    return size
                case let .ImageSize(size):
                    return size
                default:
                    break
            }
        }
        return nil
    }
    
    public func isEqual(_ other: Media) -> Bool {
        if let other = other as? TelegramMediaFile {
            if self.fileId == other.fileId {
                return true
            }
        }
        return false
    }
}

public func ==(lhs: TelegramMediaFile, rhs: TelegramMediaFile) -> Bool {
    return lhs.isEqual(rhs)
}

public func telegramMediaFileAttributesFromApiAttributes(_ attributes: [Api.DocumentAttribute]) -> [TelegramMediaFileAttribute] {
    var result: [TelegramMediaFileAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .documentAttributeFilename(fileName):
                result.append(.FileName(fileName: fileName))
            case let .documentAttributeSticker(alt, _):
                result.append(.Sticker(displayText: alt))
            case let .documentAttributeImageSize(w, h):
                result.append(.ImageSize(size: CGSize(width: CGFloat(w), height: CGFloat(h))))
            case .documentAttributeAnimated:
                result.append(.Animated)
            case let .documentAttributeVideo(duration, w, h):
                result.append(.Video(duration: Int(duration), size: CGSize(width: CGFloat(w), height: CGFloat(h))))
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                var waveformBuffer: MemoryBuffer?
                if let waveform = waveform {
                    let memory = malloc(waveform.size)!
                    memcpy(memory, waveform.data, waveform.size)
                    waveformBuffer = MemoryBuffer(memory: memory, capacity: waveform.size, length: waveform.size, freeWhenDone: true)
                }
                result.append(.Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer))
        }
    }
    return result
}

public func telegramMediaFileFromApiDocument(_ document: Api.Document) -> TelegramMediaFile? {
    switch document {
        case let .document(id, accessHash, _, mimeType, size, thumb, dcId, attributes):
            return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), location: TelegramCloudDocumentLocation(datacenterId: Int(dcId), fileId: id, accessHash: accessHash), previewRepresentations: telegramMediaImageRepresentationsFromApiSizes([thumb]), mimeType: mimeType, size: Int(size), attributes: telegramMediaFileAttributesFromApiAttributes(attributes))
        case .documentEmpty:
            return nil
    }
}
