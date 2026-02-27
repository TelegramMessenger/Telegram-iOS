import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

private let typeFileName: Int32 = 0
private let typeSticker: Int32 = 1
private let typeImageSize: Int32 = 2
private let typeAnimated: Int32 = 3
private let typeVideo: Int32 = 4
private let typeAudio: Int32 = 5
private let typeHasLinkedStickers: Int32 = 6
private let typeHintFileIsLarge: Int32 = 7
private let typeHintIsValidated: Int32 = 8
private let typeNoPremium: Int32 = 9
private let typeCustomEmoji: Int32 = 10

public enum StickerPackReference: PostboxCoding, Hashable, Equatable, Codable {
    case id(id: Int64, accessHash: Int64)
    case name(String)
    case animatedEmoji
    case dice(String)
    case animatedEmojiAnimations
    case premiumGifts
    case emojiGenericAnimations
    case iconStatusEmoji
    case iconTopicEmoji
    case iconChannelStatusEmoji
    case tonGifts
    
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
        case 5:
            self = .premiumGifts
        case 6:
            self = .iconChannelStatusEmoji
        case 7:
            self = .tonGifts
        default:
            self = .name("")
            assertionFailure()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let discriminator = try container.decode(Int32.self, forKey: "r")
        switch discriminator {
        case 0:
            self = .id(id: try container.decode(Int64.self, forKey: "i"), accessHash: try container.decode(Int64.self, forKey: "h"))
        case 1:
            self = .name(try container.decode(String.self, forKey: "n"))
        case 2:
            self = .animatedEmoji
        case 3:
            self = .dice((try? container.decode(String.self, forKey: "e")) ?? "🎲")
        case 4:
            self = .animatedEmojiAnimations
        case 5:
            self = .premiumGifts
        case 6:
            self = .iconChannelStatusEmoji
        case 7:
            self = .tonGifts
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
        case .premiumGifts:
            encoder.encodeInt32(5, forKey: "r")
        case .tonGifts:
            encoder.encodeInt32(6, forKey: "r")
        case .emojiGenericAnimations, .iconStatusEmoji, .iconTopicEmoji, .iconChannelStatusEmoji:
            preconditionFailure()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        switch self {
        case let .id(id, accessHash):
            try container.encode(0 as Int32, forKey: "r")
            try container.encode(id, forKey: "i")
            try container.encode(accessHash, forKey: "h")
        case let .name(name):
            try container.encode(1 as Int32, forKey: "r")
            try container.encode(name, forKey: "n")
        case .animatedEmoji:
            try container.encode(2 as Int32, forKey: "r")
        case let .dice(emoji):
            try container.encode(3 as Int32, forKey: "r")
            try container.encode(emoji, forKey: "e")
        case .animatedEmojiAnimations:
            try container.encode(4 as Int32, forKey: "r")
        case .premiumGifts:
            try container.encode(5 as Int32, forKey: "r")
        case .emojiGenericAnimations, .iconStatusEmoji, .iconTopicEmoji, .iconChannelStatusEmoji, .tonGifts:
            preconditionFailure()
        }
    }
    
    init(flatBuffersObject: TelegramCore_StickerPackReference) throws {
        switch flatBuffersObject.valueType {
        case .stickerpackreferenceId:
            guard let value = flatBuffersObject.value(type: TelegramCore_StickerPackReference_Id.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .id(id: value.id, accessHash: value.accessHash)
        case .stickerpackreferenceName:
            guard let value = flatBuffersObject.value(type: TelegramCore_StickerPackReference_Name.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .name(value.name)
        case .stickerpackreferenceAnimatedemoji:
            self = .animatedEmoji
        case .stickerpackreferenceDice:
            guard let value = flatBuffersObject.value(type: TelegramCore_StickerPackReference_Dice.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .dice(value.emoji)
        case .stickerpackreferenceAnimatedemojianimations:
            self = .animatedEmojiAnimations
        case .stickerpackreferencePremiumgifts:
            self = .premiumGifts
        case .stickerpackreferenceEmojigenericanimations:
            self = .emojiGenericAnimations
        case .stickerpackreferenceIconstatusemoji:
            self = .iconStatusEmoji
        case .stickerpackreferenceIcontopicemoji:
            self = .iconTopicEmoji
        case .stickerpackreferenceIconchannelstatusemoji:
            self = .iconChannelStatusEmoji
        case .stickerpackreferenceTongifts:
            self = .tonGifts
        case .none_:
            throw FlatBuffersError.missingRequiredField()
        }
    }
    
    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_StickerPackReference_Value
        let offset: Offset
        switch self {
        case let .id(id, accessHash):
            valueType = .stickerpackreferenceId
            let start = TelegramCore_StickerPackReference_Id.startStickerPackReference_Id(&builder)
            TelegramCore_StickerPackReference_Id.add(id: id, &builder)
            TelegramCore_StickerPackReference_Id.add(accessHash: accessHash, &builder)
            offset = TelegramCore_StickerPackReference_Id.endStickerPackReference_Id(&builder, start: start)
        case let .name(name):
            valueType = .stickerpackreferenceName
            let nameOffset = builder.create(string: name)
            let start = TelegramCore_StickerPackReference_Name.startStickerPackReference_Name(&builder)
            TelegramCore_StickerPackReference_Name.add(name: nameOffset, &builder)
            offset = TelegramCore_StickerPackReference_Name.endStickerPackReference_Name(&builder, start: start)
        case .animatedEmoji:
            valueType = .stickerpackreferenceAnimatedemoji
            let start = TelegramCore_StickerPackReference_AnimatedEmoji.startStickerPackReference_AnimatedEmoji(&builder)
            offset = TelegramCore_StickerPackReference_AnimatedEmoji.endStickerPackReference_AnimatedEmoji(&builder, start: start)
        case let .dice(emoji):
            valueType = .stickerpackreferenceDice
            let emojiOffset = builder.create(string: emoji)
            let start = TelegramCore_StickerPackReference_Dice.startStickerPackReference_Dice(&builder)
            TelegramCore_StickerPackReference_Dice.add(emoji: emojiOffset, &builder)
            offset = TelegramCore_StickerPackReference_Dice.endStickerPackReference_Dice(&builder, start: start)
        case .animatedEmojiAnimations:
            valueType = .stickerpackreferenceAnimatedemojianimations
            let start = TelegramCore_StickerPackReference_AnimatedEmojiAnimations.startStickerPackReference_AnimatedEmojiAnimations(&builder)
            offset = TelegramCore_StickerPackReference_AnimatedEmojiAnimations.endStickerPackReference_AnimatedEmojiAnimations(&builder, start: start)
        case .premiumGifts:
            valueType = .stickerpackreferencePremiumgifts
            let start = TelegramCore_StickerPackReference_PremiumGifts.startStickerPackReference_PremiumGifts(&builder)
            offset = TelegramCore_StickerPackReference_PremiumGifts.endStickerPackReference_PremiumGifts(&builder, start: start)
        case .emojiGenericAnimations:
            valueType = .stickerpackreferenceEmojigenericanimations
            let start = TelegramCore_StickerPackReference_EmojiGenericAnimations.startStickerPackReference_EmojiGenericAnimations(&builder)
            offset = TelegramCore_StickerPackReference_EmojiGenericAnimations.endStickerPackReference_EmojiGenericAnimations(&builder, start: start)
        case .iconStatusEmoji:
            valueType = .stickerpackreferenceIconstatusemoji
            let start = TelegramCore_StickerPackReference_IconStatusEmoji.startStickerPackReference_IconStatusEmoji(&builder)
            offset = TelegramCore_StickerPackReference_IconStatusEmoji.endStickerPackReference_IconStatusEmoji(&builder, start: start)
        case .iconTopicEmoji:
            valueType = .stickerpackreferenceIcontopicemoji
            let start = TelegramCore_StickerPackReference_IconTopicEmoji.startStickerPackReference_IconTopicEmoji(&builder)
            offset = TelegramCore_StickerPackReference_IconTopicEmoji.endStickerPackReference_IconTopicEmoji(&builder, start: start)
        case .iconChannelStatusEmoji:
            valueType = .stickerpackreferenceIconchannelstatusemoji
            let start = TelegramCore_StickerPackReference_IconChannelStatusEmoji.startStickerPackReference_IconChannelStatusEmoji(&builder)
            offset = TelegramCore_StickerPackReference_IconChannelStatusEmoji.endStickerPackReference_IconChannelStatusEmoji(&builder, start: start)
        case .tonGifts:
            valueType = .stickerpackreferenceTongifts
            let start = TelegramCore_StickerPackReference_TonGifts.startStickerPackReference_TonGifts(&builder)
            offset = TelegramCore_StickerPackReference_TonGifts.endStickerPackReference_TonGifts(&builder, start: start)
        }
        return TelegramCore_StickerPackReference.createStickerPackReference(&builder, valueType: valueType, valueOffset: offset)
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
        case .premiumGifts:
            if case .premiumGifts = rhs {
                return true
            } else {
                return false
            }
        case .tonGifts:
            if case .tonGifts = rhs {
                return true
            } else {
                return false
            }
        case .emojiGenericAnimations:
            if case .emojiGenericAnimations = rhs {
                return true
            } else {
                return false
            }
        case .iconStatusEmoji:
            if case .iconStatusEmoji = rhs {
                return true
            } else {
                return false
            }
        case .iconTopicEmoji:
            if case .iconTopicEmoji = rhs {
                return true
            } else {
                return false
            }
        case .iconChannelStatusEmoji:
            if case .iconChannelStatusEmoji = rhs {
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
    public static let isSilent = TelegramMediaVideoFlags(rawValue: 1 << 3)
}

public struct StickerMaskCoords: PostboxCoding, Equatable {
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
        self.x = Double(Float32(decoder.decodeDoubleForKey("x", orElse: 0.0)))
        self.y = Double(Float32(decoder.decodeDoubleForKey("y", orElse: 0.0)))
        self.zoom = Double(Float32(decoder.decodeDoubleForKey("z", orElse: 0.0)))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.n, forKey: "n")
        encoder.encodeDouble(self.x, forKey: "x")
        encoder.encodeDouble(self.y, forKey: "y")
        encoder.encodeDouble(self.zoom, forKey: "z")
    }
    
    init(flatBuffersObject: TelegramCore_StickerMaskCoords) {
        self.n = flatBuffersObject.n
        self.x = Double(flatBuffersObject.x)
        self.y = Double(flatBuffersObject.y)
        self.zoom = Double(flatBuffersObject.zoom)
    }
}

public enum TelegramMediaFileAttribute: PostboxCoding, Equatable {
    case FileName(fileName: String)
    case Sticker(displayText: String, packReference: StickerPackReference?, maskData: StickerMaskCoords?)
    case ImageSize(size: PixelDimensions)
    case Animated
    case Video(duration: Double, size: PixelDimensions, flags: TelegramMediaVideoFlags, preloadSize: Int32?, coverTime: Double?, videoCodec: String?)
    case Audio(isVoice: Bool, duration: Int, title: String?, performer: String?, waveform: Data?)
    case HasLinkedStickers
    case hintFileIsLarge
    case hintIsValidated
    case NoPremium
    case CustomEmoji(isPremium: Bool, isSingleColor: Bool, alt: String, packReference: StickerPackReference?)
    
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
                let duration: Double
                if let value = decoder.decodeOptionalDoubleForKey("dur") {
                    duration = value
                } else {
                    duration = Double(decoder.decodeInt32ForKey("du", orElse: 0))
                }
            
                var coverTime: Double?
                if let coverTimeValue = decoder.decodeOptionalDoubleForKey("ct") {
                    coverTime = Double(Float32(coverTimeValue))
                }
            
                self = .Video(duration: Double(Float32(duration)), size: PixelDimensions(width: decoder.decodeInt32ForKey("w", orElse: 0), height: decoder.decodeInt32ForKey("h", orElse: 0)), flags: TelegramMediaVideoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0)), preloadSize: decoder.decodeOptionalInt32ForKey("prs"), coverTime: coverTime, videoCodec: decoder.decodeOptionalStringForKey("vc"))
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
            case typeNoPremium:
                self = .NoPremium
            case typeCustomEmoji:
                self = .CustomEmoji(isPremium: decoder.decodeBoolForKey("ip", orElse: true), isSingleColor: decoder.decodeBoolForKey("sc", orElse: false), alt: decoder.decodeStringForKey("dt", orElse: ""), packReference: decoder.decodeObjectForKey("pr", decoder: { StickerPackReference(decoder: $0) }) as? StickerPackReference)
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
            case let .Video(duration, size, flags, preloadSize, coverTime, videoCodec):
                encoder.encodeInt32(typeVideo, forKey: "t")
                encoder.encodeDouble(duration, forKey: "dur")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
                encoder.encodeInt32(flags.rawValue, forKey: "f")
                if let preloadSize = preloadSize {
                    encoder.encodeInt32(preloadSize, forKey: "prs")
                } else {
                    encoder.encodeNil(forKey: "prs")
                }
                if let coverTime = coverTime {
                    encoder.encodeDouble(coverTime, forKey: "ct")
                } else {
                    encoder.encodeNil(forKey: "ct")
                }
                if let videoCodec {
                    encoder.encodeString(videoCodec, forKey: "vc")
                } else {
                    encoder.encodeNil(forKey: "vc")
                }
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
            case .NoPremium:
                encoder.encodeInt32(typeNoPremium, forKey: "t")
            case let .CustomEmoji(isPremium, isSingleColor, alt, packReference):
                encoder.encodeInt32(typeCustomEmoji, forKey: "t")
                encoder.encodeBool(isPremium, forKey: "ip")
                encoder.encodeBool(isSingleColor, forKey: "sc")
                encoder.encodeString(alt, forKey: "dt")
                if let packReference = packReference {
                    encoder.encodeObject(packReference, forKey: "pr")
                } else {
                    encoder.encodeNil(forKey: "pr")
                }
        }
    }
    
    init(flatBuffersData data: Data) throws {
        var byteBuffer = ByteBuffer(data: data)
        let flatBuffersObject: TelegramCore_TelegramMediaFileAttribute = FlatBuffers_getRoot(byteBuffer: &byteBuffer)
        try self.init(flatBuffersObject: flatBuffersObject)
    }
    
    init(flatBuffersObject: TelegramCore_TelegramMediaFileAttribute) throws {
        switch flatBuffersObject.valueType {
        case .telegrammediafileattributeFilename:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramMediaFileAttribute_FileName.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .FileName(fileName: value.fileName)
        case .telegrammediafileattributeSticker:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramMediaFileAttribute_Sticker.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .Sticker(displayText: value.displayText, packReference: try value.packReference.flatMap({ try StickerPackReference(flatBuffersObject: $0) }), maskData: value.maskData.flatMap({ StickerMaskCoords(flatBuffersObject: $0) }))
        case .telegrammediafileattributeImagesize:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramMediaFileAttribute_ImageSize.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .ImageSize(size: PixelDimensions(width: value.width, height: value.height))
        case .telegrammediafileattributeAnimated:
            self = .Animated
        case .telegrammediafileattributeVideo:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramMediaFileAttribute_Video.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .Video(duration: Double(value.duration), size: PixelDimensions(width: value.width, height: value.height), flags: TelegramMediaVideoFlags(rawValue: value.flags), preloadSize: value.preloadSize == 0 ? nil : value.preloadSize, coverTime: value.coverTime == 0.0 ? nil : Double(value.coverTime), videoCodec: value.videoCodec)
        case .telegrammediafileattributeAudio:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramMediaFileAttribute_Audio.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .Audio(isVoice: value.isVoice, duration: Int(value.duration), title: value.title, performer: value.performer, waveform: value.waveform.isEmpty ? nil : Data(value.waveform))
        case .telegrammediafileattributeHaslinkedstickers:
            self = .HasLinkedStickers
        case .telegrammediafileattributeHintfileislarge:
            self = .hintFileIsLarge
        case .telegrammediafileattributeHintisvalidated:
            self = .hintIsValidated
        case .telegrammediafileattributeNopremium:
            self = .NoPremium
        case .none_:
            throw FlatBuffersError.missingRequiredField()
        case .telegrammediafileattributeCustomemoji:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramMediaFileAttribute_CustomEmoji.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .CustomEmoji(isPremium: value.isPremium, isSingleColor: value.isSingleColor, alt: value.alt, packReference: try value.packReference.flatMap({ try StickerPackReference(flatBuffersObject: $0) }))
        }
    }

    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_TelegramMediaFileAttribute_Value
        let offset: Offset

        switch self {
        case let .FileName(fileName):
            valueType = .telegrammediafileattributeFilename
            let fileNameOffset = builder.create(string: fileName)
            let start = TelegramCore_TelegramMediaFileAttribute_FileName.startTelegramMediaFileAttribute_FileName(&builder)
            TelegramCore_TelegramMediaFileAttribute_FileName.add(fileName: fileNameOffset, &builder)
            offset = TelegramCore_TelegramMediaFileAttribute_FileName.endTelegramMediaFileAttribute_FileName(&builder, start: start)
        case let .Sticker(displayText, packReference, maskData):
            valueType = .telegrammediafileattributeSticker
            let displayTextOffset = builder.create(string: displayText)
            
            let packReferenceOffset = packReference.flatMap {
                return $0.encodeToFlatBuffers(builder: &builder)
            }
            let maskDataOffset = maskData.flatMap { maskData -> Offset in
                let start = TelegramCore_StickerMaskCoords.startStickerMaskCoords(&builder)
                TelegramCore_StickerMaskCoords.add(n: maskData.n, &builder)
                TelegramCore_StickerMaskCoords.add(x: Float32(maskData.x), &builder)
                TelegramCore_StickerMaskCoords.add(y: Float32(maskData.y), &builder)
                TelegramCore_StickerMaskCoords.add(zoom: Float32(maskData.zoom), &builder)
                return TelegramCore_StickerMaskCoords.endStickerMaskCoords(&builder, start: start)
            }
            let start = TelegramCore_TelegramMediaFileAttribute_Sticker.startTelegramMediaFileAttribute_Sticker(&builder)
            TelegramCore_TelegramMediaFileAttribute_Sticker.add(displayText: displayTextOffset, &builder)
            if let packReferenceOffset {
                TelegramCore_TelegramMediaFileAttribute_Sticker.add(packReference: packReferenceOffset, &builder)
            }
            if let maskDataOffset {
                TelegramCore_TelegramMediaFileAttribute_Sticker.add(maskData: maskDataOffset, &builder)
            }
            offset = TelegramCore_TelegramMediaFileAttribute_Sticker.endTelegramMediaFileAttribute_Sticker(&builder, start: start)
        case let .ImageSize(size):
            valueType = .telegrammediafileattributeImagesize
            let start = TelegramCore_TelegramMediaFileAttribute_ImageSize.startTelegramMediaFileAttribute_ImageSize(&builder)
            TelegramCore_TelegramMediaFileAttribute_ImageSize.add(width: size.width, &builder)
            TelegramCore_TelegramMediaFileAttribute_ImageSize.add(height: size.height, &builder)
            offset = TelegramCore_TelegramMediaFileAttribute_ImageSize.endTelegramMediaFileAttribute_ImageSize(&builder, start: start)
        case .Animated:
            valueType = .telegrammediafileattributeAnimated
            let start = TelegramCore_TelegramMediaFileAttribute_Animated.startTelegramMediaFileAttribute_Animated(&builder)
            offset = TelegramCore_TelegramMediaFileAttribute_Animated.endTelegramMediaFileAttribute_Animated(&builder, start: start)
        case let .Video(duration, size, flags, preloadSize, coverTime, videoCodec):
            valueType = .telegrammediafileattributeVideo
            let videoCodecOffset = videoCodec.flatMap { builder.create(string: $0) }
            let start = TelegramCore_TelegramMediaFileAttribute_Video.startTelegramMediaFileAttribute_Video(&builder)
            
            TelegramCore_TelegramMediaFileAttribute_Video.add(duration: Float32(duration), &builder)
            TelegramCore_TelegramMediaFileAttribute_Video.add(width: size.width, &builder)
            TelegramCore_TelegramMediaFileAttribute_Video.add(height: size.height, &builder)
            TelegramCore_TelegramMediaFileAttribute_Video.add(flags: flags.rawValue, &builder)
            TelegramCore_TelegramMediaFileAttribute_Video.add(preloadSize: preloadSize ?? 0, &builder)
            TelegramCore_TelegramMediaFileAttribute_Video.add(coverTime: Float32(coverTime ?? 0.0), &builder)
            if let videoCodecOffset {
                TelegramCore_TelegramMediaFileAttribute_Video.add(videoCodec: videoCodecOffset, &builder)}
            offset = TelegramCore_TelegramMediaFileAttribute_Video.endTelegramMediaFileAttribute_Video(&builder, start: start)
        case let .Audio(isVoice, duration, title, performer, waveform):
            valueType = .telegrammediafileattributeAudio
            let titleOffset = title.flatMap { builder.create(string: $0) }
            let performerOffset = performer.flatMap { builder.create(string: $0) }
            let waveformOffset = waveform.flatMap { builder.createVector(bytes: $0) }
            let start = TelegramCore_TelegramMediaFileAttribute_Audio.startTelegramMediaFileAttribute_Audio(&builder)
            TelegramCore_TelegramMediaFileAttribute_Audio.add(isVoice: isVoice, &builder)
            TelegramCore_TelegramMediaFileAttribute_Audio.add(duration: Int32(duration), &builder)
            if let titleOffset {
                TelegramCore_TelegramMediaFileAttribute_Audio.add(title: titleOffset, &builder)
            }
            if let performerOffset {
                TelegramCore_TelegramMediaFileAttribute_Audio.add(performer: performerOffset, &builder)
            }
            if let waveformOffset {
                TelegramCore_TelegramMediaFileAttribute_Audio.addVectorOf(waveform: waveformOffset, &builder)
            }
            offset = TelegramCore_TelegramMediaFileAttribute_Audio.endTelegramMediaFileAttribute_Audio(&builder, start: start)
        case .HasLinkedStickers:
            valueType = .telegrammediafileattributeHaslinkedstickers
            let start = TelegramCore_TelegramMediaFileAttribute_HasLinkedStickers.startTelegramMediaFileAttribute_HasLinkedStickers(&builder)
            offset = TelegramCore_TelegramMediaFileAttribute_HasLinkedStickers.endTelegramMediaFileAttribute_HasLinkedStickers(&builder, start: start)
        case .hintFileIsLarge:
            valueType = .telegrammediafileattributeHintfileislarge
            let start = TelegramCore_TelegramMediaFileAttribute_HintFileIsLarge.startTelegramMediaFileAttribute_HintFileIsLarge(&builder)
            offset = TelegramCore_TelegramMediaFileAttribute_HintFileIsLarge.endTelegramMediaFileAttribute_HintFileIsLarge(&builder, start: start)
        case .hintIsValidated:
            valueType = .telegrammediafileattributeHintisvalidated
            let start = TelegramCore_TelegramMediaFileAttribute_HintIsValidated.startTelegramMediaFileAttribute_HintIsValidated(&builder)
            offset = TelegramCore_TelegramMediaFileAttribute_HintIsValidated.endTelegramMediaFileAttribute_HintIsValidated(&builder, start: start)
        case .NoPremium:
            valueType = .telegrammediafileattributeNopremium
            let start = TelegramCore_TelegramMediaFileAttribute_NoPremium.startTelegramMediaFileAttribute_NoPremium(&builder)
            offset = TelegramCore_TelegramMediaFileAttribute_NoPremium.endTelegramMediaFileAttribute_NoPremium(&builder, start: start)
        case let .CustomEmoji(isPremium, isSingleColor, alt, packReference):
            valueType = .telegrammediafileattributeCustomemoji
            let altOffset = builder.create(string: alt)
            let packReferenceOffset = packReference.flatMap {
                return $0.encodeToFlatBuffers(builder: &builder)
            }
            let start = TelegramCore_TelegramMediaFileAttribute_CustomEmoji.startTelegramMediaFileAttribute_CustomEmoji(&builder)
            TelegramCore_TelegramMediaFileAttribute_CustomEmoji.add(isPremium: isPremium, &builder)
            TelegramCore_TelegramMediaFileAttribute_CustomEmoji.add(isSingleColor: isSingleColor, &builder)
            TelegramCore_TelegramMediaFileAttribute_CustomEmoji.add(alt: altOffset, &builder)
            if let packReferenceOffset {
                TelegramCore_TelegramMediaFileAttribute_CustomEmoji.add(packReference: packReferenceOffset, &builder)
            }
            offset = TelegramCore_TelegramMediaFileAttribute_CustomEmoji.endTelegramMediaFileAttribute_CustomEmoji(&builder, start: start)
        }

        return TelegramCore_TelegramMediaFileAttribute.createTelegramMediaFileAttribute(&builder, valueType: valueType, valueOffset: offset)
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
    public struct Accessor: Equatable {
        let _wrappedFile: TelegramMediaFile?
        let _wrapped: TelegramCore_TelegramMediaFile?
        let _wrappedData: Data?
        
        public init(_ wrapped: TelegramCore_TelegramMediaFile, _ _wrappedData: Data) {
            self._wrapped = wrapped
            self._wrappedData = _wrappedData
            self._wrappedFile = nil
        }
        
        public init(_ wrapped: TelegramMediaFile) {
            self._wrapped = nil
            self._wrappedData = nil
            self._wrappedFile = wrapped
        }
        
        public func _parse() -> TelegramMediaFile {
            if let _wrappedFile = self._wrappedFile {
                return _wrappedFile
            } else {
                return try! TelegramMediaFile(flatBuffersObject: self._wrapped!)
            }
        }
        
        public static func ==(lhs: TelegramMediaFile.Accessor, rhs: TelegramMediaFile.Accessor) -> Bool {
            if let lhsWrappedFile = lhs._wrappedFile, let rhsWrappedFile = rhs._wrappedFile {
                return lhsWrappedFile === rhsWrappedFile
            } else if let lhsWrappedData = lhs._wrappedData, let rhsWrappedData = rhs._wrappedData {
                return lhsWrappedData == rhsWrappedData
            } else {
                return lhs._parse() == rhs._parse()
            }
        }
    }
    
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
        
        public init(flatBuffersObject: TelegramCore_VideoThumbnail) throws {
            self.dimensions = PixelDimensions(width: flatBuffersObject.width, height: flatBuffersObject.height)
            self.resource = try TelegramMediaResource_parse(flatBuffersObject: flatBuffersObject.resource)
        }
        
        public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
            let resourceOffset = TelegramMediaResource_serialize(resource: self.resource, flatBuffersBuilder: &builder)!
            
            let start = TelegramCore_VideoThumbnail.startVideoThumbnail(&builder)
            
            TelegramCore_VideoThumbnail.add(width: self.dimensions.width, &builder)
            TelegramCore_VideoThumbnail.add(height: self.dimensions.height, &builder)
            TelegramCore_VideoThumbnail.add(resource: resourceOffset, &builder)
            
            return TelegramCore_VideoThumbnail.endVideoThumbnail(&builder, start: start)
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
    public let videoCover: TelegramMediaImage?
    public let immediateThumbnailData: Data?
    public let mimeType: String
    public let size: Int64?
    public let attributes: [TelegramMediaFileAttribute]
    public let alternativeRepresentations: [TelegramMediaFile]
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
    
    public init(
        fileId: MediaId,
        partialReference: PartialMediaReference?,
        resource: TelegramMediaResource,
        previewRepresentations: [TelegramMediaImageRepresentation],
        videoThumbnails: [TelegramMediaFile.VideoThumbnail],
        videoCover: TelegramMediaImage? = nil,
        immediateThumbnailData: Data?,
        mimeType: String,
        size: Int64?,
        attributes: [TelegramMediaFileAttribute],
        alternativeRepresentations: [TelegramMediaFile]
    ) {
        self.fileId = fileId
        self.partialReference = partialReference
        self.resource = resource
        self.previewRepresentations = previewRepresentations
        self.videoThumbnails = videoThumbnails
        self.videoCover = videoCover
        self.immediateThumbnailData = immediateThumbnailData
        self.mimeType = mimeType
        self.size = size
        self.attributes = attributes
        self.alternativeRepresentations = alternativeRepresentations
    }
    
    public init(decoder: PostboxDecoder) {
        self.fileId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        self.partialReference = decoder.decodeAnyObjectForKey("prf", decoder: { PartialMediaReference(decoder: $0) }) as? PartialMediaReference
        self.resource = decoder.decodeObjectForKey("r") as? TelegramMediaResource ?? EmptyMediaResource()
        self.previewRepresentations = decoder.decodeObjectArrayForKey("pr")
        self.videoThumbnails = decoder.decodeObjectArrayForKey("vr")
        self.videoCover = decoder.decodeObjectForKey("cv", decoder: { TelegramMediaImage(decoder: $0) }) as? TelegramMediaImage
        self.immediateThumbnailData = decoder.decodeDataForKey("itd")
        self.mimeType = decoder.decodeStringForKey("mt", orElse: "")
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int64(size)
        } else {
            self.size = nil
        }
        self.attributes = decoder.decodeObjectArrayForKey("at")
        if let altMedia = try? decoder.decodeObjectArrayWithCustomDecoderForKey("arep", decoder: { d in
            return d.decodeRootObject()
        }) {
            self.alternativeRepresentations = altMedia.compactMap { $0 as? TelegramMediaFile }
        } else {
            self.alternativeRepresentations = []
        }
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
        if let videoCover = self.videoCover {
            encoder.encodeObject(videoCover, forKey: "cv")
        } else {
            encoder.encodeNil(forKey: "cv")
        }
        if let immediateThumbnailData = self.immediateThumbnailData {
            encoder.encodeData(immediateThumbnailData, forKey: "itd")
        } else {
            encoder.encodeNil(forKey: "itd")
        }
        encoder.encodeString(self.mimeType, forKey: "mt")
        if let size = self.size {
            encoder.encodeInt64(size, forKey: "s64")
        } else {
            encoder.encodeNil(forKey: "s64")
        }
        encoder.encodeObjectArray(self.attributes, forKey: "at")
        encoder.encodeObjectArrayWithEncoder(self.alternativeRepresentations, forKey: "arep", encoder: { v, e in
            e.encodeRootObject(v)
        })
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
        self.videoCover = object.videoCover
        self.immediateThumbnailData = object.immediateThumbnailData
        self.mimeType = object.mimeType
        self.size = object.size
        self.attributes = object.attributes
        self.alternativeRepresentations = object.alternativeRepresentations
    }
    
    public func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        postboxEncoder.encodeRootObject(self)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postboxEncoder.makeData(), forKey: .data)
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramMediaFile) throws {
        self.fileId = MediaId(namespace: flatBuffersObject.fileId.namespace, id: flatBuffersObject.fileId.id)
        self.partialReference = try flatBuffersObject.partialReference.flatMap { try PartialMediaReference(flatBuffersObject: $0 ) }
        self.resource = try TelegramMediaResource_parse(flatBuffersObject: flatBuffersObject.resource)
        self.previewRepresentations = try (0 ..< flatBuffersObject.previewRepresentationsCount).map { i in
            return try TelegramMediaImageRepresentation(flatBuffersObject: flatBuffersObject.previewRepresentations(at: i)!)
        }
        self.videoThumbnails = try (0 ..< flatBuffersObject.videoThumbnailsCount).map { i in
            return try VideoThumbnail(flatBuffersObject: flatBuffersObject.videoThumbnails(at: i)!)
        }
        self.videoCover = try flatBuffersObject.videoCover.flatMap { try TelegramMediaImage(flatBuffersObject: $0) }
        self.immediateThumbnailData = flatBuffersObject.immediateThumbnailData.isEmpty ? nil : Data(flatBuffersObject.immediateThumbnailData)
        self.mimeType = flatBuffersObject.mimeType
        self.size = flatBuffersObject.size == Int64.min ? nil : flatBuffersObject.size
        self.attributes = try (0 ..< flatBuffersObject.attributesCount).map { i in
            return try TelegramMediaFileAttribute(flatBuffersObject: flatBuffersObject.attributes(at: i)!)
        }
        self.alternativeRepresentations = try (0 ..< flatBuffersObject.alternativeRepresentationsCount).map { i in
            return try TelegramMediaFile(flatBuffersObject: flatBuffersObject.alternativeRepresentations(at: i)!)
        }
    }
    
    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let partialReferenceOffset = self.partialReference.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        
        let resourceOffset = TelegramMediaResource_serialize(resource: self.resource, flatBuffersBuilder: &builder)!
        
        let previewRepresentationsOffsets = self.previewRepresentations.map { attribute in
            return attribute.encodeToFlatBuffers(builder: &builder)
        }
        let previewRepresentationsOffset = builder.createVector(ofOffsets: previewRepresentationsOffsets, len: previewRepresentationsOffsets.count)
        
        let videoThumbnailsOffsets = self.videoThumbnails.map { videoThumbnail in
            return videoThumbnail.encodeToFlatBuffers(builder: &builder)
        }
        let videoThumbnailsOffset = builder.createVector(ofOffsets: videoThumbnailsOffsets, len: videoThumbnailsOffsets.count)
        
        let videoCoverOffset = self.videoCover.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        
        let immediateThumbnailDataOffset = self.immediateThumbnailData.flatMap { builder.createVector(bytes: $0) }
        
        let mimeTypeOffset = builder.create(string: self.mimeType)
        
        let attributesOffsets = self.attributes.map { attribute in
            return attribute.encodeToFlatBuffers(builder: &builder)
        }
        let attributesOffset = builder.createVector(ofOffsets: attributesOffsets, len: attributesOffsets.count)
        
        let alternativeRepresentationsOffsets = self.alternativeRepresentations.map { alternativeRepresentation in
            return alternativeRepresentation.encodeToFlatBuffers(builder: &builder)
        }
        let alternativeRepresentationsOffset = builder.createVector(ofOffsets: alternativeRepresentationsOffsets, len: alternativeRepresentationsOffsets.count)
        
        let start = TelegramCore_TelegramMediaFile.startTelegramMediaFile(&builder)
        
        TelegramCore_TelegramMediaFile.add(fileId: TelegramCore_MediaId(namespace: self.fileId.namespace, id: self.fileId.id), &builder)
        if let partialReferenceOffset {
            TelegramCore_TelegramMediaFile.add(partialReference: partialReferenceOffset, &builder)
        }
        TelegramCore_TelegramMediaFile.add(resource: resourceOffset, &builder)
        TelegramCore_TelegramMediaFile.addVectorOf(previewRepresentations: previewRepresentationsOffset, &builder)
        TelegramCore_TelegramMediaFile.addVectorOf(videoThumbnails: videoThumbnailsOffset, &builder)
        if let immediateThumbnailDataOffset {
            TelegramCore_TelegramMediaFile.addVectorOf(immediateThumbnailData: immediateThumbnailDataOffset, &builder)
        }
        if let videoCoverOffset {
            TelegramCore_TelegramMediaFile.add(videoCover: videoCoverOffset, &builder)
        }
        TelegramCore_TelegramMediaFile.add(mimeType: mimeTypeOffset, &builder)
        TelegramCore_TelegramMediaFile.add(size: self.size ?? Int64.min, &builder)
        TelegramCore_TelegramMediaFile.addVectorOf(attributes: attributesOffset, &builder)
        TelegramCore_TelegramMediaFile.addVectorOf(alternativeRepresentations: alternativeRepresentationsOffset, &builder)
        
        return TelegramCore_TelegramMediaFile.endTelegramMediaFile(&builder, start: start)
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
    
    public var isStaticEmoji: Bool {
        for attribute in self.attributes {
            if case .CustomEmoji = attribute {
                return self.mimeType == "image/webp"
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
            if case .Video(_, _, let flags, _, _, _) = attribute {
                return flags.contains(.instantRoundVideo)
            }
        }
        return false
    }
    
    public var preloadSize: Int32? {
        for attribute in self.attributes {
            if case .Video(_, _, _, let preloadSize, _, _) = attribute {
                return preloadSize
            }
        }
        return nil
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
    
    public var isPremiumSticker: Bool {
        if let _ = self.videoThumbnails.first(where: { thumbnail in
            if let resource = thumbnail.resource as? CloudDocumentSizeMediaResource, resource.sizeSpec == "f" {
                return true
            } else {
                return false
            }
        }) {
            return true
        }
        return false
    }
    
    public var noPremium: Bool {
        for attribute in self.attributes {
            if case .NoPremium = attribute {
                return true
            }
        }
        return false
    }
    
    public var premiumEffect: TelegramMediaFile.VideoThumbnail? {
        if let effect = self.videoThumbnails.first(where: { thumbnail in
            if let resource = thumbnail.resource as? CloudDocumentSizeMediaResource, resource.sizeSpec == "f" {
                return true
            } else {
                return false
            }
        }) {
            return effect
        }
        return nil
    }
    
    public var isVideoSticker: Bool {
        if self.mimeType == "video/webm" {
            var hasSticker = false
            for attribute in self.attributes {
                if case .Sticker = attribute {
                    hasSticker = true
                    break
                } else if case .CustomEmoji = attribute {
                    hasSticker = true
                    break
                }
            }
            return hasSticker
        }
        return false
    }
    
    public var isCustomEmoji: Bool {
        var hasSticker = false
        for attribute in self.attributes {
            if case .CustomEmoji = attribute {
                hasSticker = true
                break
            }
        }
        return hasSticker
    }
    
    public var isCustomTemplateEmoji: Bool {
        for attribute in self.attributes {
            if case let .CustomEmoji(_, isSingleColor, _, packReference) = attribute, let packReference = packReference {
                if isSingleColor {
                    return true
                }
                switch packReference {
                case let .id(id, _):
                    if id == 1269403972611866647 {
                        return true
                    }
                default:
                    break
                }
                break
            }
        }
        return false
    }
    
    public var isPremiumEmoji: Bool {
        for attribute in self.attributes {
            if case let .CustomEmoji(isPremium, _, _, _) = attribute {
                return isPremium
            }
        }
        return false
    }
    
    public var isVideoEmoji: Bool {
        if self.mimeType == "video/webm" {
            var hasSticker = false
            for attribute in self.attributes {
                if case .CustomEmoji = attribute {
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
        var hasNonVoiceAudio = false
        var hasVideo = false
        for attribute in self.attributes {
            if case .Audio(false, _, _, _, _) = attribute {
                hasNonVoiceAudio = true
            } else if case .Video = attribute {
                hasVideo = true
            }
        }
        return hasNonVoiceAudio && !hasVideo
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
        
        if self.videoCover != other.videoCover {
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
        
        if self.attributes != other.attributes {
            return false
        }
        
        if !areMediaArraysEqual(self.alternativeRepresentations, other.alternativeRepresentations) {
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
        
        if !areMediaArraysSemanticallyEqual(self.alternativeRepresentations, other.alternativeRepresentations) {
            return false
        }
        
        return true
    }
    
    public func withUpdatedPartialReference(_ partialReference: PartialMediaReference?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, videoCover: self.videoCover, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes, alternativeRepresentations: self.alternativeRepresentations)
    }

    public func withUpdatedResource(_ resource: TelegramMediaResource) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, videoCover: self.videoCover, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes, alternativeRepresentations: self.alternativeRepresentations)
    }
    
    public func withUpdatedSize(_ size: Int64?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, videoCover: self.videoCover, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: size, attributes: self.attributes, alternativeRepresentations: self.alternativeRepresentations)
    }
    
    public func withUpdatedPreviewRepresentations(_ previewRepresentations: [TelegramMediaImageRepresentation]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: previewRepresentations, videoThumbnails: self.videoThumbnails, videoCover: self.videoCover, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes, alternativeRepresentations: self.alternativeRepresentations)
    }
    
    public func withUpdatedAttributes(_ attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, videoCover: self.videoCover, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: attributes, alternativeRepresentations: self.alternativeRepresentations)
    }
    
    public func withUpdatedVideoCover(_ videoCover: TelegramMediaImage?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, videoCover: videoCover, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes, alternativeRepresentations: self.alternativeRepresentations)
    }
}

public func ==(lhs: TelegramMediaFile, rhs: TelegramMediaFile) -> Bool {
    return lhs.isEqual(to: rhs)
}

public extension TelegramMediaFile.Accessor {
    var fileId: MediaId {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.fileId
        }
        return MediaId(namespace: self._wrapped!.fileId.namespace, id: self._wrapped!.fileId.id)
    }
    
    var id: MediaId {
        return self.fileId
    }
    
    var fileName: String? {
        get {
            if let _wrappedFile = self._wrappedFile {
                return _wrappedFile.fileName
            }
            for i in 0 ..< self._wrapped!.attributesCount {
                let attribute = self._wrapped!.attributes(at: i)!
                if attribute.valueType == .telegrammediafileattributeFilename {
                    if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_FileName.self) {
                        return value.fileName
                    }
                }
            }
            return nil
        }
    }
    
    var isSticker: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isSticker
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeSticker {
                return true
            }
        }
        return false
    }
    
    var isStaticSticker: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isStaticSticker
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeSticker {
                if self._wrapped!.size != Int64.min, self._wrapped!.size < 300 * 1024 {
                    return !isAnimatedSticker
                } else if self._wrapped!.size == Int64.min {
                    return !isAnimatedSticker
                }
                return false
            }
        }
        return false
    }
    
    var isStaticEmoji: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isStaticEmoji
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeCustomemoji {
                return self._wrapped!.mimeType == "image/webp"
            }
        }
        return false
    }
    
    var isVideo: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isVideo
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeVideo {
                return true
            }
        }
        return false
    }
    
    var isInstantVideo: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isInstantVideo
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeVideo {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_Video.self) {
                    return TelegramMediaVideoFlags(rawValue: value.flags).contains(.instantRoundVideo)
                }
            }
        }
        return false
    }
    
    var preloadSize: Int32? {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.preloadSize
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeVideo {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_Video.self) {
                    return value.preloadSize == 0 ? nil : value.preloadSize
                }
            }
        }
        return nil
    }
    
    var isAnimated: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isAnimated
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeAnimated {
                return true
            }
        }
        return false
    }
    
    var isAnimatedSticker: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isAnimatedSticker
        }
        if self._wrapped!.mimeType == "application/x-tgsticker" && self.fileName != nil {
            return true
        }
        return false
    }
    
    var isPremiumSticker: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isPremiumSticker
        }
        for i in 0 ..< self._wrapped!.videoThumbnailsCount {
            let thumbnail = self._wrapped!.videoThumbnails(at: i)!
            if thumbnail.resource.valueType == .telegrammediaresourceClouddocumentsizemediaresource {
                if let value = thumbnail.resource.value(type: TelegramCore_TelegramMediaResource_CloudDocumentSizeMediaResource.self) {
                    if value.sizeSpec == "f" {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    var noPremium: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.noPremium
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeNopremium {
                return true
            }
        }
        return false
    }
    
    var premiumEffect: TelegramMediaFile.VideoThumbnail? {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.premiumEffect
        }
        for i in 0 ..< self._wrapped!.videoThumbnailsCount {
            let thumbnail = self._wrapped!.videoThumbnails(at: i)!
            if thumbnail.resource.valueType == .telegrammediaresourceClouddocumentsizemediaresource {
                if let value = thumbnail.resource.value(type: TelegramCore_TelegramMediaResource_CloudDocumentSizeMediaResource.self) {
                    if value.sizeSpec == "f" {
                        return try! TelegramMediaFile.VideoThumbnail(flatBuffersObject: thumbnail)
                    }
                }
            }
        }
        return nil
    }
    
    var isVideoSticker: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isVideoSticker
        }
        if self._wrapped!.mimeType == "video/webm" {
            var hasSticker = false
            for i in 0 ..< self._wrapped!.attributesCount {
                let attribute = self._wrapped!.attributes(at: i)!
                if attribute.valueType == .telegrammediafileattributeSticker {
                    hasSticker = true
                    break
                } else if attribute.valueType == .telegrammediafileattributeCustomemoji {
                    hasSticker = true
                    break
                }
            }
            return hasSticker
        }
        return false
    }
    
    var isCustomEmoji: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isCustomEmoji
        }
        var hasSticker = false
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeCustomemoji {
                hasSticker = true
                break
            }
        }
        return hasSticker
    }
    
    var customEmojiAlt: String? {
        if let _wrappedFile = self._wrappedFile {
            for attribute in _wrappedFile.attributes {
                if case let .CustomEmoji(_, _, alt, _) = attribute {
                    return alt
                }
            }
            return nil
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeCustomemoji {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_CustomEmoji.self) {
                    return value.alt
                }
                break
            }
        }
        return nil
    }
    
    var stickerDisplayText: String? {
        if let _wrappedFile = self._wrappedFile {
            for attribute in _wrappedFile.attributes {
                if case let .Sticker(displayText, _, _) = attribute {
                    return displayText
                }
            }
            return nil
        }
        
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeSticker {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_Sticker.self) {
                    return value.displayText
                }
            }
        }
        
        return nil
    }
    
    var isCustomTemplateEmoji: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isCustomTemplateEmoji
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeCustomemoji {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_CustomEmoji.self) {
                    let isSingleColor = value.isSingleColor
                    if isSingleColor {
                        return true
                    }
                    
                    if let packReference = value.packReference {
                        if packReference.valueType == .stickerpackreferenceId {
                            if let value = packReference.value(type: TelegramCore_StickerPackReference_Id.self) {
                                if value.id == 1269403972611866647 {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    var internal_isHardcodedTemplateEmoji: Bool {
        if let _wrappedFile = self._wrappedFile {
            for attribute in _wrappedFile.attributes {
                if case let .CustomEmoji(_, _, _, packReference) = attribute {
                    switch packReference {
                    case let .id(id, _):
                        if id == 773947703670341676 || id == 2964141614563343 {
                            return true
                        }
                    default:
                        break
                    }
                }
            }
            return false
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeCustomemoji {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_CustomEmoji.self) {
                    if let packReference = value.packReference {
                        if packReference.valueType == .stickerpackreferenceId {
                            if let value = packReference.value(type: TelegramCore_StickerPackReference_Id.self) {
                                if value.id == 773947703670341676 || value.id == 2964141614563343 {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    var isPremiumEmoji: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isPremiumEmoji
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeCustomemoji {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_CustomEmoji.self) {
                    return value.isPremium
                }
            }
        }
        return false
    }
    
    var isVideoEmoji: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isVideoEmoji
        }
        if self._wrapped!.mimeType == "video/webm" {
            var hasSticker = false
            for i in 0 ..< self._wrapped!.attributesCount {
                let attribute = self._wrapped!.attributes(at: i)!
                if attribute.valueType == .telegrammediafileattributeCustomemoji {
                    hasSticker = true
                    break
                }
            }
            return hasSticker
        }
        return false
    }
    
    var hasLinkedStickers: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.hasLinkedStickers
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeHaslinkedstickers {
                return true
            }
        }
        return false
    }
    
    var isMusic: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isMusic
        }
        
        var hasNonVoiceAudio = false
        var hasVideo = false
        
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeAudio {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_Audio.self) {
                    if !value.isVoice {
                        hasNonVoiceAudio = true
                    }
                }
            } else if attribute.valueType == .telegrammediafileattributeVideo {
                hasVideo = true
            }
        }
        return hasNonVoiceAudio && !hasVideo
    }
    
    var isVoice: Bool {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.isVoice
        }
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeAudio {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_Audio.self) {
                    return value.isVoice
                }
            }
        }
        return false
    }
    
    var dimensions: PixelDimensions? {
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.dimensions
        }
        
        for i in 0 ..< self._wrapped!.attributesCount {
            let attribute = self._wrapped!.attributes(at: i)!
            if attribute.valueType == .telegrammediafileattributeVideo {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_Video.self) {
                    return PixelDimensions(width: value.width, height: value.height)
                }
            } else if attribute.valueType == .telegrammediafileattributeImagesize {
                if let value = attribute.value(type: TelegramCore_TelegramMediaFileAttribute_ImageSize.self) {
                    return PixelDimensions(width: value.width, height: value.height)
                }
            }
        }
        
        if self.isAnimatedSticker {
            return PixelDimensions(width: 512, height: 512)
        } else {
            return nil
        }
    }
    
    var immediateThumbnailData: Data? {
        //TODO:release defer parsing
        if let _wrappedFile = self._wrappedFile {
            return _wrappedFile.immediateThumbnailData
        }
        
        return _wrapped!.immediateThumbnailData.isEmpty ? nil : Data(_wrapped!.immediateThumbnailData)
    }
}
