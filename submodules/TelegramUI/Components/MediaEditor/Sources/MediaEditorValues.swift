import Foundation
import UIKit
import Display
import TelegramCore
import AVFoundation
import VideoToolbox

public enum EditorToolKey: Int32, CaseIterable {
    case enhance
    case brightness
    case contrast
    case saturation
    case warmth
    case fade
    case highlights
    case shadows
    case vignette
    case grain
    case sharpen
    case shadowsTint
    case highlightsTint
    case blur
    case curves
    case stickerOutline
    
    static let adjustmentToolsKeys: [EditorToolKey] = [
        .enhance,
        .brightness,
        .contrast,
        .saturation,
        .warmth,
        .fade,
        .highlights,
        .shadows,
        .vignette,
        .grain,
        .sharpen
    ]
}

public struct VideoPositionChange: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case additional
        case timestamp
    }
    
    public let additional: Bool
    public let timestamp: Double
    
    public init(
        additional: Bool,
        timestamp: Double
    ) {
        self.additional = additional
        self.timestamp = timestamp
    }
}

public struct MediaAudioTrack: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case path
        case artist
        case title
        case duration
    }
    
    public let path: String
    public let artist: String?
    public let title: String?
    public let duration: Double
    
    public init(
        path: String,
        artist: String?,
        title: String?,
        duration: Double
    ) {
        self.path = path
        self.artist = artist
        self.title = title
        self.duration = duration
    }
}

public struct MediaAudioTrackSamples: Equatable {
    private enum CodingKeys: String, CodingKey {
        case samples
        case peak
    }
    
    public let samples: Data
    public let peak: Int32
    
    public init(
        samples: Data,
        peak: Int32
    ) {
        self.samples = samples
        self.peak = peak
    }
}

public enum MediaQualityPreset: Int32 {
    case compressedDefault
    case compressedVeryLow
    case compressedLow
    case compressedMedium
    case compressedHigh
    case compressedVeryHigh
    case animation
    case videoMessage
    case profileLow
    case profile
    case profileHigh
    case profileVeryHigh
    case sticker
    case passthrough

    var hasAudio: Bool {
        switch self {
        case .animation, .profileLow, .profile, .profileHigh, .profileVeryHigh, .sticker:
            return false
        default:
            return true
        }
    }
    
    var maximumDimensions: CGFloat {
        switch self {
        case .compressedVeryLow:
            return 480.0
        case .compressedLow:
            return 640.0
        case .compressedMedium:
            return 848.0
        case .compressedHigh:
            return 1280.0
        case .compressedVeryHigh:
            return 1920.0
        case .videoMessage:
            return 400.0
        case .profileLow:
            return 720.0
        case .profile, .profileHigh, .profileVeryHigh:
            return 800.0
        case .sticker:
            return 512.0
        default:
            return 848.0
        }
    }
    
    var videoBitrateKbps: Int {
        switch self {
        case .compressedVeryLow:
            return 400
        case .compressedLow:
            return 700
        case .compressedMedium:
            return 1600
        case .compressedHigh:
            return 3000
        case .compressedVeryHigh:
            return 6600
        case .videoMessage:
            return 1000
        case .profileLow:
            return 1100
        case .profile:
            return 1500
        case .profileHigh:
            return 2000
        case .profileVeryHigh:
            return 2400
        case .sticker:
            return 1000
        default:
            return 900
        }
    }
    
    var audioBitrateKbps: Int {
        switch self {
        case .compressedVeryLow, .compressedLow:
            return 32
        case .compressedMedium, .compressedHigh, .compressedVeryHigh, .videoMessage:
            return 64
        default:
            return 0
        }
    }
    
    var audioChannelsCount: Int {
        switch self {
        case .compressedVeryLow, .compressedLow:
            return 1
        default:
            return 2
        }
    }
}

public enum MediaCropOrientation: Int32 {
    case up
    case down
    case left
    case right
    
    var rotation: CGFloat {
        switch self {
        case .up:
            return 0.0
        case .down:
            return .pi
        case .left:
            return .pi / 2.0
        case .right:
            return -.pi / 2.0
        }
    }
    
    var isSideward: Bool {
        switch self {
        case .left, .right:
            return true
        default:
            return false
        }
    }
}

public final class MediaEditorValues: Codable, Equatable {
    public static func == (lhs: MediaEditorValues, rhs: MediaEditorValues) -> Bool {
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.originalDimensions != rhs.originalDimensions {
            return false
        }
        if lhs.cropOffset != rhs.cropOffset {
            return false
        }
        if lhs.cropRect != rhs.cropRect {
            return false
        }
        if lhs.cropScale != rhs.cropScale {
            return false
        }
        if lhs.cropRotation != rhs.cropRotation {
            return false
        }
        if lhs.cropMirroring != rhs.cropMirroring {
            return false
        }
        if lhs.cropOrientation != rhs.cropOrientation {
            return false
        }
        if lhs.gradientColors != rhs.gradientColors {
            return false
        }
        if lhs.videoTrimRange != rhs.videoTrimRange {
            return false
        }
        if lhs.videoIsMuted != rhs.videoIsMuted {
            return false
        }
        if lhs.videoIsFullHd != rhs.videoIsFullHd {
            return false
        }
        if lhs.videoIsMirrored != rhs.videoIsMirrored {
            return false
        }
        if lhs.videoVolume != rhs.videoVolume {
            return false
        }
        if lhs.additionalVideoPath != rhs.additionalVideoPath {
            return false
        }
        if lhs.additionalVideoIsDual != rhs.additionalVideoIsDual {
            return false
        }
        if lhs.additionalVideoPosition != rhs.additionalVideoPosition {
            return false
        }
        if lhs.additionalVideoScale != rhs.additionalVideoScale {
            return false
        }
        if lhs.additionalVideoRotation != rhs.additionalVideoRotation {
            return false
        }
        if lhs.additionalVideoPositionChanges != rhs.additionalVideoPositionChanges {
            return false
        }
        if lhs.additionalVideoTrimRange != rhs.additionalVideoTrimRange {
            return false
        }
        if lhs.additionalVideoOffset != rhs.additionalVideoOffset {
            return false
        }
        if lhs.additionalVideoVolume != rhs.additionalVideoVolume {
            return false
        }
        if lhs.collage != rhs.collage {
            return false
        }
        if lhs.drawing !== rhs.drawing {
            return false
        }
        if lhs.maskDrawing !== rhs.maskDrawing {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.audioTrack != rhs.audioTrack {
            return false
        }
        if lhs.audioTrackTrimRange != rhs.audioTrackTrimRange {
            return false
        }
        if lhs.audioTrackOffset != rhs.audioTrackOffset {
            return false
        }
        if lhs.audioTrackVolume != rhs.audioTrackVolume {
            return false
        }
        if lhs.audioTrackSamples != rhs.audioTrackSamples {
            return false
        }
        if lhs.collageTrackSamples != rhs.collageTrackSamples {
            return false
        }
        if lhs.coverImageTimestamp != rhs.coverImageTimestamp {
            return false
        }
        if lhs.nightTheme != rhs.nightTheme {
            return false
        }
        
        for key in EditorToolKey.allCases {
            let lhsToolValue = lhs.toolValues[key]
            let rhsToolValue = rhs.toolValues[key]
            if (lhsToolValue == nil) != (rhsToolValue == nil) {
                return false
            }
            if let lhsToolValue = lhsToolValue as? Float, let rhsToolValue = rhsToolValue as? Float {
                if lhsToolValue != rhsToolValue {
                    return false
                }
            }
            if let lhsToolValue = lhsToolValue as? BlurValue, let rhsToolValue = rhsToolValue as? BlurValue {
                if lhsToolValue != rhsToolValue {
                    return false
                }
            }
            if let lhsToolValue = lhsToolValue as? TintValue, let rhsToolValue = rhsToolValue as? TintValue {
                if lhsToolValue != rhsToolValue {
                    return false
                }
            }
            if let lhsToolValue = lhsToolValue as? CurvesValue, let rhsToolValue = rhsToolValue as? CurvesValue {
                if lhsToolValue != rhsToolValue {
                    return false
                }
            }
        }
        
        return true
    }
    
    private enum CodingKeys: String, CodingKey {
        case peerId
        case originalWidth
        case originalHeight
        case cropOffset
        case cropRect
        case cropScale
        case cropRotation
        case cropMirroring
        case cropOrientation
        case gradientColors
        case videoTrimRange
        case videoIsMuted
        case videoIsFullHd
        case videoIsMirrored
        case videoVolume
        case additionalVideoPath
        case additionalVideoIsDual
        case additionalVideoPosition
        case additionalVideoScale
        case additionalVideoRotation
        case additionalVideoPositionChanges
        case additionalVideoTrimRange
        case additionalVideoOffset
        case additionalVideoVolume
        case collage
        
        case nightTheme
        case drawing
        case maskDrawing
        case entities
        case toolValues
        case audioTrack
        case audioTrackTrimRange
        case audioTrackOffset
        case audioTrackVolume
        case coverImageTimestamp
        case qualityPreset
    }
    
    public struct VideoCollageItem: Codable, Equatable {
        enum DecodingError: Error {
            case generic
        }
        
        private enum CodingKeys: String, CodingKey {
            case contentType
            case contentValue
            case isVideo
            case frame
            case contentScale
            case contentOffset
            case videoTrimRange
            case videoOffset
            case videoVolume
        }
        
        public enum Content: Equatable {
            case main
            case imageFile(path: String)
            case videoFile(path: String)
            case asset(localIdentifier: String, isVideo: Bool)
            
            public var isVideo: Bool {
                switch self {
                case .videoFile, .asset(_, true):
                    return true
                default:
                    return false
                }
            }
        }
        
        public let content: Content
        public let frame: CGRect
        public let contentScale: CGFloat
        public let contentOffset: CGPoint
        
        public let videoTrimRange: Range<Double>?
        public let videoOffset: Double?
        public let videoVolume: CGFloat?
        
        public init(
            content: Content,
            frame: CGRect,
            contentScale: CGFloat,
            contentOffset: CGPoint,
            videoTrimRange: Range<Double>?,
            videoOffset: Double?,
            videoVolume: CGFloat?
        ) {
            self.content = content
            self.frame = frame
            self.contentScale = contentScale
            self.contentOffset = contentOffset
            self.videoTrimRange = videoTrimRange
            self.videoOffset = videoOffset
            self.videoVolume = videoVolume
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Int32.self, forKey: .contentType) {
            case 0:
                self.content = .main
            case 1:
                self.content = .imageFile(path: try container.decode(String.self, forKey: .contentValue))
            case 2:
                self.content = .videoFile(path: try container.decode(String.self, forKey: .contentValue))
            case 3:
                self.content = .asset(localIdentifier: try container.decode(String.self, forKey: .contentValue), isVideo: try container.decode(Bool.self, forKey: .isVideo))
            default:
                throw DecodingError.generic
            }
            self.frame = try container.decode(CGRect.self, forKey: .frame)
            
            self.contentScale = try container.decodeIfPresent(CGFloat.self, forKey: .contentScale) ?? 1.0
            self.contentOffset = try container.decodeIfPresent(CGPoint.self, forKey: .contentOffset) ?? .zero
            
            self.videoTrimRange = try container.decodeIfPresent(Range<Double>.self, forKey: .videoTrimRange)
            self.videoOffset = try container.decodeIfPresent(Double.self, forKey: .videoOffset)
            self.videoVolume = try container.decodeIfPresent(CGFloat.self, forKey: .videoVolume)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self.content {
            case .main:
                try container.encode(Int32(0), forKey: .contentType)
            case let .imageFile(value):
                try container.encode(Int32(1), forKey: .contentType)
                try container.encode(value, forKey: .contentValue)
            case let .videoFile(value):
                try container.encode(Int32(2), forKey: .contentType)
                try container.encode(value, forKey: .contentValue)
            case let .asset(value, isVideo):
                try container.encode(Int32(3), forKey: .contentType)
                try container.encode(value, forKey: .contentValue)
                try container.encode(isVideo, forKey: .isVideo)
            }
            try container.encode(self.frame, forKey: .frame)
            try container.encode(self.contentScale, forKey: .contentScale)
            try container.encode(self.contentOffset, forKey: .contentOffset)
            try container.encodeIfPresent(self.videoTrimRange, forKey: .videoTrimRange)
            try container.encodeIfPresent(self.videoOffset, forKey: .videoOffset)
            try container.encodeIfPresent(self.videoVolume, forKey: .videoVolume)
        }
        
        func withUpdatedVideoTrimRange(_ videoTrimRange: Range<Double>?) -> VideoCollageItem {
            return VideoCollageItem(
                content: self.content,
                frame: self.frame,
                contentScale: self.contentScale,
                contentOffset: self.contentOffset,
                videoTrimRange: videoTrimRange,
                videoOffset: self.videoOffset,
                videoVolume: self.videoVolume
            )
        }
        
        func withUpdatedVideoOffset(_ videoOffset: Double?) -> VideoCollageItem {
            return VideoCollageItem(
                content: self.content,
                frame: self.frame,
                contentScale: self.contentScale,
                contentOffset: self.contentOffset,
                videoTrimRange: self.videoTrimRange,
                videoOffset: videoOffset,
                videoVolume: self.videoVolume
            )
        }
        
        func withUpdatedVideoVolume(_ videoVolume: CGFloat?) -> VideoCollageItem {
            return VideoCollageItem(
                content: self.content,
                frame: self.frame,
                contentScale: self.contentScale,
                contentOffset: self.contentOffset,
                videoTrimRange: self.videoTrimRange,
                videoOffset: self.videoOffset,
                videoVolume: videoVolume
            )
        }
    }
    
    public let peerId: EnginePeer.Id
    
    public let originalDimensions: PixelDimensions
    public let cropOffset: CGPoint
    public let cropRect: CGRect?
    public let cropScale: CGFloat
    public let cropRotation: CGFloat
    public let cropMirroring: Bool
    public let cropOrientation: MediaCropOrientation?
    
    public let gradientColors: [UIColor]?
    
    public let videoTrimRange: Range<Double>?
    public let videoIsMuted: Bool
    public let videoIsFullHd: Bool
    public let videoIsMirrored: Bool
    public let videoVolume: CGFloat?
    
    public let additionalVideoPath: String?
    public let additionalVideoIsDual: Bool
    public let additionalVideoPosition: CGPoint?
    public let additionalVideoScale: CGFloat?
    public let additionalVideoRotation: CGFloat?
    public let additionalVideoPositionChanges: [VideoPositionChange]
        
    public let additionalVideoTrimRange: Range<Double>?
    public let additionalVideoOffset: Double?
    public let additionalVideoVolume: CGFloat?
    
    public let collage: [VideoCollageItem]
    
    public let nightTheme: Bool
    public let drawing: UIImage?
    public let maskDrawing: UIImage?
    public let entities: [CodableDrawingEntity]
    public let toolValues: [EditorToolKey: Any]
    
    public let audioTrack: MediaAudioTrack?
    public let audioTrackTrimRange: Range<Double>?
    public let audioTrackOffset: Double?
    public let audioTrackVolume: CGFloat?
    public let audioTrackSamples: MediaAudioTrackSamples?
    
    public let collageTrackSamples: MediaAudioTrackSamples?
    
    public let coverImageTimestamp: Double?
    
    public let qualityPreset: MediaQualityPreset?
    
    var isStory: Bool {
        return self.qualityPreset == nil
    }
    
    var isSticker: Bool {
        return self.qualityPreset == .sticker
    }
    
    var isAvatar: Bool {
        return [.profile].contains(self.qualityPreset)
    }
    
    public var cropValues: (offset: CGPoint, rotation: CGFloat, scale: CGFloat) {
        return (self.cropOffset, self.cropRotation, self.cropScale)
    }
    
    public init(
        peerId: EnginePeer.Id,
        originalDimensions: PixelDimensions,
        cropOffset: CGPoint,
        cropRect: CGRect?,
        cropScale: CGFloat,
        cropRotation: CGFloat,
        cropMirroring: Bool,
        cropOrientation: MediaCropOrientation?,
        gradientColors: [UIColor]?,
        videoTrimRange: Range<Double>?,
        videoIsMuted: Bool,
        videoIsFullHd: Bool,
        videoIsMirrored: Bool,
        videoVolume: CGFloat?,
        additionalVideoPath: String?,
        additionalVideoIsDual: Bool,
        additionalVideoPosition: CGPoint?,
        additionalVideoScale: CGFloat?,
        additionalVideoRotation: CGFloat?,
        additionalVideoPositionChanges: [VideoPositionChange],
        additionalVideoTrimRange: Range<Double>?,
        additionalVideoOffset: Double?,
        additionalVideoVolume: CGFloat?,
        collage: [VideoCollageItem],
        nightTheme: Bool,
        drawing: UIImage?,
        maskDrawing: UIImage?,
        entities: [CodableDrawingEntity],
        toolValues: [EditorToolKey: Any],
        audioTrack: MediaAudioTrack?,
        audioTrackTrimRange: Range<Double>?,
        audioTrackOffset: Double?,
        audioTrackVolume: CGFloat?,
        audioTrackSamples: MediaAudioTrackSamples?,
        collageTrackSamples: MediaAudioTrackSamples?,
        coverImageTimestamp: Double?,
        qualityPreset: MediaQualityPreset?
    ) {
        self.peerId = peerId
        self.originalDimensions = originalDimensions
        self.cropOffset = cropOffset
        self.cropRect = cropRect
        self.cropScale = cropScale
        self.cropRotation = cropRotation
        self.cropMirroring = cropMirroring
        self.cropOrientation = cropOrientation
        self.gradientColors = gradientColors
        self.videoTrimRange = videoTrimRange
        self.videoIsMuted = videoIsMuted
        self.videoIsFullHd = videoIsFullHd
        self.videoIsMirrored = videoIsMirrored
        self.videoVolume = videoVolume
        self.additionalVideoPath = additionalVideoPath
        self.additionalVideoIsDual = additionalVideoIsDual
        self.additionalVideoPosition = additionalVideoPosition
        self.additionalVideoScale = additionalVideoScale
        self.additionalVideoRotation = additionalVideoRotation
        self.additionalVideoPositionChanges = additionalVideoPositionChanges
        self.additionalVideoTrimRange = additionalVideoTrimRange
        self.additionalVideoOffset = additionalVideoOffset
        self.additionalVideoVolume = additionalVideoVolume
        self.collage = collage
        self.nightTheme = nightTheme
        self.drawing = drawing
        self.maskDrawing = maskDrawing
        self.entities = entities
        self.toolValues = toolValues
        self.audioTrack = audioTrack
        self.audioTrackTrimRange = audioTrackTrimRange
        self.audioTrackOffset = audioTrackOffset
        self.audioTrackVolume = audioTrackVolume
        self.audioTrackSamples = audioTrackSamples
        self.collageTrackSamples = collageTrackSamples
        self.coverImageTimestamp = coverImageTimestamp
        self.qualityPreset = qualityPreset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.peerId = EnginePeer.Id(try container.decodeIfPresent(Int64.self, forKey: .peerId) ?? 0)
        
        let width = try container.decode(Int32.self, forKey: .originalWidth)
        let height = try container.decode(Int32.self, forKey: .originalHeight)
        self.originalDimensions = PixelDimensions(width: width, height: height)
        
        self.cropOffset = try container.decode(CGPoint.self, forKey: .cropOffset)
        self.cropRect = try container.decodeIfPresent(CGRect.self, forKey: .cropRect)
        self.cropScale = try container.decode(CGFloat.self, forKey: .cropScale)
        self.cropRotation = try container.decode(CGFloat.self, forKey: .cropRotation)
        self.cropMirroring = try container.decode(Bool.self, forKey: .cropMirroring)
        self.cropOrientation = (try container.decodeIfPresent(Int32.self, forKey: .cropOrientation)).flatMap { MediaCropOrientation(rawValue: $0) }
        
        if let gradientColors = try container.decodeIfPresent([DrawingColor].self, forKey: .gradientColors) {
            self.gradientColors = gradientColors.map { $0.toUIColor() }
        } else {
            self.gradientColors = nil
        }
        
        self.videoTrimRange = try container.decodeIfPresent(Range<Double>.self, forKey: .videoTrimRange)
        self.videoIsMuted = try container.decode(Bool.self, forKey: .videoIsMuted)
        self.videoIsFullHd = try container.decodeIfPresent(Bool.self, forKey: .videoIsFullHd) ?? false
        self.videoIsMirrored = try container.decodeIfPresent(Bool.self, forKey: .videoIsMirrored) ?? false
        self.videoVolume = try container.decodeIfPresent(CGFloat.self, forKey: .videoVolume) ?? 1.0
        
        self.additionalVideoPath = try container.decodeIfPresent(String.self, forKey: .additionalVideoPath)
        self.additionalVideoIsDual = try container.decodeIfPresent(Bool.self, forKey: .additionalVideoIsDual) ?? false
        self.additionalVideoPosition = try container.decodeIfPresent(CGPoint.self, forKey: .additionalVideoPosition)
        self.additionalVideoScale = try container.decodeIfPresent(CGFloat.self, forKey: .additionalVideoScale)
        self.additionalVideoRotation = try container.decodeIfPresent(CGFloat.self, forKey: .additionalVideoRotation)
        self.additionalVideoPositionChanges = try container.decodeIfPresent([VideoPositionChange].self, forKey: .additionalVideoPositionChanges) ?? []
        self.additionalVideoTrimRange = try container.decodeIfPresent(Range<Double>.self, forKey: .additionalVideoTrimRange)
        self.additionalVideoOffset = try container.decodeIfPresent(Double.self, forKey: .additionalVideoOffset)
        self.additionalVideoVolume = try container.decodeIfPresent(CGFloat.self, forKey: .additionalVideoVolume)
        
        self.collage = try container.decodeIfPresent([VideoCollageItem].self, forKey: .collage) ?? []
        
        self.nightTheme = try container.decodeIfPresent(Bool.self, forKey: .nightTheme) ?? false
        if let drawingData = try container.decodeIfPresent(Data.self, forKey: .drawing), let image = UIImage(data: drawingData) {
            self.drawing = image
        } else {
            self.drawing = nil
        }
        if let drawingData = try container.decodeIfPresent(Data.self, forKey: .maskDrawing), let image = UIImage(data: drawingData) {
            self.maskDrawing = image
        } else {
            self.maskDrawing = nil
        }
        
        self.entities = try container.decode([CodableDrawingEntity].self, forKey: .entities)
        
        let values = try container.decode([CodableToolValue].self, forKey: .toolValues)
        var toolValues: [EditorToolKey: Any] = [:]
        for value in values {
            let (key, value) = value.keyAndValue
            toolValues[key] = value
        }
        self.toolValues = toolValues
        
        self.audioTrack = try container.decodeIfPresent(MediaAudioTrack.self, forKey: .audioTrack)
        self.audioTrackTrimRange = try container.decodeIfPresent(Range<Double>.self, forKey: .audioTrackTrimRange)
        self.audioTrackOffset = try container.decodeIfPresent(Double.self, forKey: .audioTrackOffset)
        self.audioTrackVolume = try container.decodeIfPresent(CGFloat.self, forKey: .audioTrackVolume)
        
        self.audioTrackSamples = nil
        self.collageTrackSamples = nil
        
        self.coverImageTimestamp = try container.decodeIfPresent(Double.self, forKey: .coverImageTimestamp)
        
        self.qualityPreset = (try container.decodeIfPresent(Int32.self, forKey: .qualityPreset)).flatMap { MediaQualityPreset(rawValue: $0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.peerId.toInt64(), forKey: .peerId)
        
        try container.encode(self.originalDimensions.width, forKey: .originalWidth)
        try container.encode(self.originalDimensions.height, forKey: .originalHeight)
        
        try container.encode(self.cropOffset, forKey: .cropOffset)
        try container.encode(self.cropRect, forKey: .cropRect)
        try container.encode(self.cropScale, forKey: .cropScale)
        try container.encode(self.cropRotation, forKey: .cropRotation)
        try container.encode(self.cropMirroring, forKey: .cropMirroring)
        try container.encodeIfPresent(self.cropOrientation?.rawValue, forKey: .cropOrientation)
        
        if let gradientColors = self.gradientColors {
            try container.encode(gradientColors.map { DrawingColor(color: $0) }, forKey: .gradientColors)
        }
        
        try container.encodeIfPresent(self.videoTrimRange, forKey: .videoTrimRange)
        try container.encode(self.videoIsMuted, forKey: .videoIsMuted)
        try container.encode(self.videoIsFullHd, forKey: .videoIsFullHd)
        try container.encode(self.videoIsMirrored, forKey: .videoIsMirrored)
        try container.encode(self.videoVolume, forKey: .videoVolume)
        
        try container.encodeIfPresent(self.additionalVideoPath, forKey: .additionalVideoPath)
        try container.encodeIfPresent(self.additionalVideoIsDual, forKey: .additionalVideoIsDual)
        try container.encodeIfPresent(self.additionalVideoPosition, forKey: .additionalVideoPosition)
        try container.encodeIfPresent(self.additionalVideoScale, forKey: .additionalVideoScale)
        try container.encodeIfPresent(self.additionalVideoRotation, forKey: .additionalVideoRotation)
        try container.encodeIfPresent(self.additionalVideoPositionChanges, forKey: .additionalVideoPositionChanges)
        try container.encodeIfPresent(self.additionalVideoTrimRange, forKey: .additionalVideoTrimRange)
        try container.encodeIfPresent(self.additionalVideoOffset, forKey: .additionalVideoOffset)
        try container.encodeIfPresent(self.additionalVideoVolume, forKey: .additionalVideoVolume)
        
        try container.encode(self.collage, forKey: .collage)
        
        try container.encode(self.nightTheme, forKey: .nightTheme)
        if let drawing = self.drawing, let pngDrawingData = drawing.pngData() {
            try container.encode(pngDrawingData, forKey: .drawing)
        }
        if let drawing = self.maskDrawing, let pngDrawingData = drawing.pngData() {
            try container.encode(pngDrawingData, forKey: .maskDrawing)
        }
        
        try container.encode(self.entities, forKey: .entities)
        
        var values: [CodableToolValue] = []
        for (key, value) in self.toolValues {
            if let toolValue = CodableToolValue(key: key, value: value) {
                values.append(toolValue)
            }
        }
        try container.encode(values, forKey: .toolValues)
        
        try container.encodeIfPresent(self.audioTrack, forKey: .audioTrack)
        try container.encodeIfPresent(self.audioTrackTrimRange, forKey: .audioTrackTrimRange)
        try container.encodeIfPresent(self.audioTrackOffset, forKey: .audioTrackOffset)
        try container.encodeIfPresent(self.audioTrackVolume, forKey: .audioTrackVolume)
        
        try container.encodeIfPresent(self.coverImageTimestamp, forKey: .coverImageTimestamp)
        
        try container.encodeIfPresent(self.qualityPreset?.rawValue, forKey: .qualityPreset)
    }
    
    public func makeCopy() -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedCrop(offset: CGPoint, scale: CGFloat, rotation: CGFloat, mirroring: Bool) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: offset, cropRect: self.cropRect, cropScale: scale, cropRotation: rotation, cropMirroring: mirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    public func withUpdatedCropRect(cropRect: CGRect, rotation: CGFloat, mirroring: Bool) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: .zero, cropRect: cropRect, cropScale: 1.0, cropRotation: rotation, cropMirroring: mirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedGradientColors(gradientColors: [UIColor]) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedVideoIsMuted(_ videoIsMuted: Bool) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedVideoIsFullHd(_ videoIsFullHd: Bool) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    
    func withUpdatedVideoIsMirrored(_ videoIsMirrored: Bool) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedVideoVolume(_ videoVolume: CGFloat?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAdditionalVideo(path: String?, isDual: Bool, positionChanges: [VideoPositionChange]) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: path, additionalVideoIsDual: isDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: positionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAdditionalVideo(position: CGPoint, scale: CGFloat, rotation: CGFloat) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: position, additionalVideoScale: scale, additionalVideoRotation: rotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAdditionalVideoTrimRange(_ additionalVideoTrimRange: Range<Double>?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    
    func withUpdatedAdditionalVideoOffset(_ additionalVideoOffset: Double?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAdditionalVideoVolume(_ additionalVideoVolume: CGFloat?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedCollage(_ collage: [VideoCollageItem]) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedVideoTrimRange(_ videoTrimRange: Range<Double>) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedDrawingAndEntities(drawing: UIImage?, entities: [CodableDrawingEntity]) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: drawing, maskDrawing: self.maskDrawing, entities: entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    public func withUpdatedMaskDrawing(maskDrawing: UIImage?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedToolValues(_ toolValues: [EditorToolKey: Any]) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAudioTrack(_ audioTrack: MediaAudioTrack?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAudioTrackTrimRange(_ audioTrackTrimRange: Range<Double>?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAudioTrackOffset(_ audioTrackOffset: Double?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAudioTrackVolume(_ audioTrackVolume: CGFloat?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedAudioTrackSamples(_ audioTrackSamples: MediaAudioTrackSamples?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedCollageTrackSamples(_ collageTrackSamples: MediaAudioTrackSamples?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    func withUpdatedNightTheme(_ nightTheme: Bool) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    public func withUpdatedEntities(_ entities: [CodableDrawingEntity]) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    public func withUpdatedCoverImageTimestamp(_ coverImageTimestamp: Double?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: coverImageTimestamp, qualityPreset: self.qualityPreset)
    }
    
    public func withUpdatedQualityPreset(_ qualityPreset: MediaQualityPreset?) -> MediaEditorValues {
        return MediaEditorValues(peerId: self.peerId, originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropRect: self.cropRect, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, cropOrientation: self.cropOrientation, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, videoVolume: self.videoVolume, additionalVideoPath: self.additionalVideoPath, additionalVideoIsDual: self.additionalVideoIsDual, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, additionalVideoTrimRange: self.additionalVideoTrimRange, additionalVideoOffset: self.additionalVideoOffset, additionalVideoVolume: self.additionalVideoVolume, collage: self.collage, nightTheme: self.nightTheme, drawing: self.drawing, maskDrawing: self.maskDrawing, entities: self.entities, toolValues: self.toolValues, audioTrack: self.audioTrack, audioTrackTrimRange: self.audioTrackTrimRange, audioTrackOffset: self.audioTrackOffset, audioTrackVolume: self.audioTrackVolume, audioTrackSamples: self.audioTrackSamples, collageTrackSamples: self.collageTrackSamples, coverImageTimestamp: self.coverImageTimestamp, qualityPreset: qualityPreset)
    }
    
    public var resultDimensions: PixelDimensions {
        if self.videoIsFullHd {
            return PixelDimensions(width: 1080, height: 1920)
        } else {
            return PixelDimensions(width: 720, height: 1280)
        }
    }
    
    public var hasChanges: Bool {
        if self.cropOffset != .zero {
            return true
        }
        if self.cropScale != 1.0 {
            return true
        }
        if self.cropRotation != 0.0 {
            return true
        }
        if self.cropMirroring {
            return true
        }
        if (self.cropOrientation ?? .up) != .up {
            return true
        }
        if self.videoTrimRange != nil {
            return true
        }
        if self.drawing != nil {
            return true
        }
        if !self.entities.isEmpty {
            return true
        }
        if !self.toolValues.isEmpty {
            return true
        }
        if self.audioTrack != nil {
            return true
        }
        return false
    }
}

public struct TintValue: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case color
        case intensity
    }
    
    public static let initial = TintValue(
        color: .clear,
        intensity: 0.5
    )
    
    public let color: UIColor
    public let intensity: Float
    
    public init(
        color: UIColor,
        intensity: Float
    ) {
        self.color = color
        self.intensity = intensity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.color = try container.decode(DrawingColor.self, forKey: .color).toUIColor()
        self.intensity = try container.decode(Float.self, forKey: .intensity)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(DrawingColor(color: self.color), forKey: .color)
        try container.encode(self.intensity, forKey: .intensity)
    }
    
    public func withUpdatedColor(_ color: UIColor) -> TintValue {
        return TintValue(color: color, intensity: self.intensity)
    }
    
    public func withUpdatedIntensity(_ intensity: Float) -> TintValue {
        return TintValue(color: self.color, intensity: intensity)
    }
}

public struct BlurValue: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case mode
        case intensity
        case position
        case size
        case falloff
        case rotation
    }
    
    public static let initial = BlurValue(
        mode: .off,
        intensity: 0.5,
        position: CGPoint(x: 0.5, y: 0.5),
        size: 0.24,
        falloff: 0.12,
        rotation: 0.0
    )
    
    public enum Mode: Int32, Equatable {
        case off
        case radial
        case linear
        case portrait
    }
    
    public let mode: Mode
    public let intensity: Float
    public let position: CGPoint
    public let size: Float
    public let falloff: Float
    public let rotation: Float
    
    public init(
        mode: Mode,
        intensity: Float,
        position: CGPoint,
        size: Float,
        falloff: Float,
        rotation: Float
    ) {
        self.mode = mode
        self.intensity = intensity
        self.position = position
        self.size = size
        self.falloff = falloff
        self.rotation = rotation
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.mode = try BlurValue.Mode(rawValue: container.decode(Int32.self, forKey: .mode)) ?? .off
        self.intensity = try container.decode(Float.self, forKey: .intensity)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.size = try container.decode(Float.self, forKey: .size)
        self.falloff = try container.decode(Float.self, forKey: .falloff)
        self.rotation = try container.decode(Float.self, forKey: .rotation)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.mode.rawValue, forKey: .mode)
        try container.encode(self.intensity, forKey: .intensity)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.size, forKey: .size)
        try container.encode(self.falloff, forKey: .falloff)
        try container.encode(self.rotation, forKey: .rotation)
    }
    
    public func withUpdatedMode(_ mode: Mode) -> BlurValue {
        return BlurValue(
            mode: mode,
            intensity: self.intensity,
            position: self.position,
            size: self.size,
            falloff: self.falloff,
            rotation: self.rotation
        )
    }
    
    public func withUpdatedIntensity(_ intensity: Float) -> BlurValue {
        return BlurValue(
            mode: self.mode,
            intensity: intensity,
            position: self.position,
            size: self.size,
            falloff: self.falloff,
            rotation: self.rotation
        )
    }
    
    public func withUpdatedPosition(_ position: CGPoint) -> BlurValue {
        return BlurValue(
            mode: self.mode,
            intensity: self.intensity,
            position: position,
            size: self.size,
            falloff: self.falloff,
            rotation: self.rotation
        )
    }
    
    public func withUpdatedSize(_ size: Float) -> BlurValue {
        return BlurValue(
            mode: self.mode,
            intensity: self.intensity,
            position: self.position,
            size: size,
            falloff: self.falloff,
            rotation: self.rotation
        )
    }
    
    public func withUpdatedFalloff(_ falloff: Float) -> BlurValue {
        return BlurValue(
            mode: self.mode,
            intensity: self.intensity,
            position: self.position,
            size: self.size,
            falloff: falloff,
            rotation: self.rotation
        )
    }
    
    public func withUpdatedRotation(_ rotation: Float) -> BlurValue {
        return BlurValue(
            mode: self.mode,
            intensity: self.intensity,
            position: self.position,
            size: self.size,
            falloff: self.falloff,
            rotation: rotation
        )
    }
}

public struct CurvesValue: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case all
        case red
        case green
        case blue
    }
    
    public struct CurveValue: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case blacks
            case shadows
            case midtones
            case highlights
            case whites
        }
        
        public static let initial = CurveValue(
            blacks: 0.0,
            shadows: 0.25,
            midtones: 0.5,
            highlights: 0.75,
            whites: 1.0
        )
        
        public let blacks: Float
        public let shadows: Float
        public let midtones: Float
        public let highlights: Float
        public let whites: Float
        
        lazy var dataPoints: [Float] = {
            let points: [Float] = [
                self.blacks,
                self.blacks,
                self.shadows,
                self.midtones,
                self.highlights,
                self.whites,
                self.whites
            ]
            
            let (_, dataPoints) = curveThroughPoints(
                count: points.count,
                valueAtIndex: { index in
                    return points[index]
                },
                positionAtIndex: { index, _ in
                    switch index {
                    case 0:
                        return -0.001
                    case 1:
                        return 0.0
                    case 2:
                        return 0.25
                    case 3:
                        return 0.5
                    case 4:
                        return 0.75
                    case 5:
                        return 1.0
                    default:
                        return 1.001
                    }
                },
                size: CGSize(width: 1.0, height: 1.0),
                type: .line,
                granularity: 100,
                floor: false
            )
            return dataPoints
        }()
        
        public init(
            blacks: Float,
            shadows: Float,
            midtones: Float,
            highlights: Float,
            whites: Float
        ) {
            self.blacks = blacks
            self.shadows = shadows
            self.midtones = midtones
            self.highlights = highlights
            self.whites = whites
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.blacks = try container.decode(Float.self, forKey: .blacks)
            self.shadows = try container.decode(Float.self, forKey: .shadows)
            self.midtones = try container.decode(Float.self, forKey: .midtones)
            self.highlights = try container.decode(Float.self, forKey: .highlights)
            self.whites = try container.decode(Float.self, forKey: .whites)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.blacks, forKey: .blacks)
            try container.encode(self.shadows, forKey: .shadows)
            try container.encode(self.midtones, forKey: .midtones)
            try container.encode(self.highlights, forKey: .highlights)
            try container.encode(self.whites, forKey: .whites)
        }
        
        public func withUpdatedBlacks(_ blacks: Float) -> CurveValue {
            return CurveValue(blacks: blacks, shadows: self.shadows, midtones: self.midtones, highlights: self.highlights, whites: self.whites)
        }
        
        public func withUpdatedShadows(_ shadows: Float) -> CurveValue {
            return CurveValue(blacks: self.blacks, shadows: shadows, midtones: self.midtones, highlights: self.highlights, whites: self.whites)
        }
        
        public func withUpdatedMidtones(_ midtones: Float) -> CurveValue {
            return CurveValue(blacks: self.blacks, shadows: self.shadows, midtones: midtones, highlights: self.highlights, whites: self.whites)
        }
        
        public func withUpdatedHighlights(_ highlights: Float) -> CurveValue {
            return CurveValue(blacks: self.blacks, shadows: self.shadows, midtones: self.midtones, highlights: highlights, whites: self.whites)
        }
        
        public func withUpdatedWhites(_ whites: Float) -> CurveValue {
            return CurveValue(blacks: self.blacks, shadows: self.shadows, midtones: self.midtones, highlights: self.highlights, whites: whites)
        }
    }
    
    public static let initial = CurvesValue(
        all: CurveValue.initial,
        red: CurveValue.initial,
        green: CurveValue.initial,
        blue: CurveValue.initial
    )
    
    public var all: CurveValue
    public var red: CurveValue
    public var green: CurveValue
    public var blue: CurveValue
    
    public init(
        all: CurveValue,
        red: CurveValue,
        green: CurveValue,
        blue: CurveValue
    ) {
        self.all = all
        self.red = red
        self.green = green
        self.blue = blue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.all = try container.decode(CurveValue.self, forKey: .all)
        self.red = try container.decode(CurveValue.self, forKey: .red)
        self.green = try container.decode(CurveValue.self, forKey: .green)
        self.blue = try container.decode(CurveValue.self, forKey: .blue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.all, forKey: .all)
        try container.encode(self.red, forKey: .red)
        try container.encode(self.green, forKey: .green)
        try container.encode(self.blue, forKey: .blue)
    }
    
    public func withUpdatedAll(_ all: CurveValue) -> CurvesValue {
        return CurvesValue(all: all, red: self.red, green: self.green, blue: self.blue)
    }
    
    public func withUpdatedRed(_ red: CurveValue) -> CurvesValue {
        return CurvesValue(all: self.all, red: red, green: self.green, blue: self.blue)
    }
    
    public func withUpdatedGreen(_ green: CurveValue) -> CurvesValue {
        return CurvesValue(all: self.all, red: self.red, green: green, blue: self.blue)
    }
    
    public func withUpdatedBlue(_ blue: CurveValue) -> CurvesValue {
        return CurvesValue(all: self.all, red: self.red, green: self.green, blue: blue)
    }
}


private let toolEpsilon: Float = 0.005
public extension MediaEditorValues {
    var hasAdjustments: Bool {
        for key in EditorToolKey.adjustmentToolsKeys {
            if let value = self.toolValues[key] as? Float, abs(value) > toolEpsilon {
                return true
            }
        }
        return false
    }
    
    var hasTint: Bool {
        if let tintValue = self.toolValues[.shadowsTint] as? TintValue, tintValue.color != .clear && tintValue.intensity > toolEpsilon {
            return true
        } else if let tintValue = self.toolValues[.highlightsTint] as? TintValue, tintValue.color != .clear && tintValue.intensity > toolEpsilon {
            return true
        } else {
            return false
        }
    }
    
    var hasBlur: Bool {
        if let blurValue = self.toolValues[.blur] as? BlurValue, blurValue.mode != .off && blurValue.intensity > toolEpsilon {
            return true
        } else {
            return false
        }
    }
    
    var hasCurves: Bool {
        if let curvesValue = self.toolValues[.curves] as? CurvesValue, curvesValue != CurvesValue.initial {
            return true
        } else {
            return false
        }
    }
    
    var requiresComposing: Bool {
        if abs(1.0 - self.cropScale) > 0.0 {
            return true
        }
        if self.cropRect != nil {
            return true
        }
        if self.cropOffset != .zero {
            return true
        }
        if abs(self.cropRotation) > 0.0 {
            return true
        }
        if self.cropMirroring {
            return true
        }
        if self.hasAdjustments {
            return true
        }
        if self.hasTint {
            return true
        }
        if self.hasBlur {
            return true
        }
        if self.hasCurves {
            return true
        }
        if self.drawing != nil {
            return true
        }
        if !self.entities.isEmpty {
            return true
        }
        if self.additionalVideoPath != nil {
            return true
        }
        return false
    }
}

public class MediaEditorHistogram: Equatable {
    public class HistogramBins: Equatable {
        public static func == (lhs: HistogramBins, rhs: HistogramBins) -> Bool {
            if lhs.count != rhs.count {
                return false
            }
            if lhs.max != rhs.max {
                return false
            }
            if lhs.values != rhs.values {
                return false
            }
            return true
        }
        
        let values: [UInt32]
        let max: UInt32
        
        public var count: Int {
            return self.values.count
        }
        
        init(values: [UInt32], max: UInt32) {
            self.values = values
            self.max = max
        }
        
        public func valueAtIndex(_ index: Int, mirrored: Bool = false) -> Float {
            if index >= 0 && index < values.count, self.max > 0 {
                let value = Float(self.values[index]) / Float(self.max)
                return mirrored ? 1.0 - value : value
            } else {
                return 0.0
            }
        }
    }
    
    public static func == (lhs: MediaEditorHistogram, rhs: MediaEditorHistogram) -> Bool {
        if lhs.luminance != rhs.luminance {
            return false
        }
        if lhs.red != rhs.red {
            return false
        }
        if lhs.green != rhs.green {
            return false
        }
        if lhs.blue != rhs.blue {
            return false
        }
        return true
    }
    
    public let luminance: HistogramBins
    public let red: HistogramBins
    public let green: HistogramBins
    public let blue: HistogramBins
    
    public init(data: Data) {
        let count = 256
        
        var maxRed: UInt32 = 0
        var redValues: [UInt32] = []
        var maxGreen: UInt32 = 0
        var greenValues: [UInt32] = []
        var maxBlue: UInt32 = 0
        var blueValues: [UInt32] = []
        var maxLuma: UInt32 = 0
        var lumaValues: [UInt32] = []
        
        data.withUnsafeBytes { pointer in
            if let red = pointer.baseAddress?.assumingMemoryBound(to: UInt32.self) {
                for i in 0 ..< count {
                    redValues.append(red[i])
                    if red[i] > maxRed {
                        maxRed = red[i]
                    }
                }
            }
            
            if let green = pointer.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: count) {
                for i in 0 ..< count {
                    greenValues.append(green[i])
                    if green[i] > maxGreen {
                        maxGreen = green[i]
                    }
                }
            }
            
            if let blue = pointer.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: count * 2) {
                for i in 0 ..< count {
                    blueValues.append(blue[i])
                    if blue[i] > maxBlue {
                        maxBlue = blue[i]
                    }
                }
            }
            
            if let luma = pointer.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: count * 3) {
                for i in 0 ..< count {
                    lumaValues.append(luma[i])
                    if luma[i] > maxLuma {
                        maxLuma = luma[i]
                    }
                }
            }
        }
        
        self.luminance = HistogramBins(values: lumaValues, max: maxLuma)
        self.red = HistogramBins(values: redValues, max: maxRed)
        self.green = HistogramBins(values: greenValues, max: maxGreen)
        self.blue = HistogramBins(values: blueValues, max: maxBlue)
    }
    
    init(
        luminance: HistogramBins,
        red: HistogramBins,
        green: HistogramBins,
        blue: HistogramBins
    ) {
        self.luminance = luminance
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum MediaEditorCurveType {
    case filled
    case line
}

public func curveThroughPoints(count: Int, valueAtIndex: (Int) -> Float, positionAtIndex: (Int, CGFloat) -> CGFloat, size: CGSize, type: MediaEditorCurveType, granularity: Int, floor: Bool) -> (UIBezierPath, [Float]) {
    let path = UIBezierPath()
    var dataPoints: [Float] = []
    
    let firstValue = valueAtIndex(0)
    switch type {
    case .filled:
        path.move(to: CGPoint(x: -1.0, y: size.height))
        path.addLine(to: CGPoint(x: -1.0, y: CGFloat(firstValue) * size.height))
    case .line:
        path.move(to: CGPoint(x: -1.0, y: CGFloat(firstValue) * size.height))
    }
    
    let step = size.width / CGFloat(count)
    func pointAtIndex(_ index: Int) -> CGPoint {
        if floor {
            return CGPoint(x: floorToScreenPixels(positionAtIndex(index, step)), y: floorToScreenPixels(CGFloat(valueAtIndex(index)) * size.height))
        } else {
            return CGPoint(x: positionAtIndex(index, step), y: CGFloat(valueAtIndex(index)) * size.height)
        }
    }
    
    for index in 1 ..< count - 2 {
        let point0 = pointAtIndex(index - 1)
        let point1 = pointAtIndex(index)
        let point2 = pointAtIndex(index + 1)
        let point3 = pointAtIndex(index + 2)
        
        for j in 1 ..< granularity {
            let t = CGFloat(j) * (1.0 / CGFloat(granularity))
            let tt = t * t
            let ttt = tt * t
            
            var point = CGPoint(
                x: 0.5 * (2 * point1.x + (point2.x - point0.x) * t + (2 * point0.x - 5 * point1.x + 4 * point2.x - point3.x) * tt + (3 * point1.x - point0.x - 3 * point2.x + point3.x) * ttt),
                y: 0.5 * (2 * point1.y + (point2.y - point0.y) * t + (2 * point0.y - 5 * point1.y + 4 * point2.y - point3.y) * tt + (3 * point1.y - point0.y - 3 * point2.y + point3.y) * ttt)
            )
            point.y = max(0.0, min(size.height, point.y))
            if point.x > point0.x {
                path.addLine(to: point)
            }
            
            if ((j - 1) % 2 == 0) {
                dataPoints.append(Float(point.y))
            }
        }
        path.addLine(to: point2)
    }
    
    let lastValue = valueAtIndex(count - 1)
    path.addLine(to: CGPoint(x: size.width + 1.0, y: CGFloat(lastValue) * size.height))
    
    if case .filled = type {
        path.addLine(to: CGPoint(x: size.width + 1.0, y: size.height))
        path.close()
    }
    
    return (path, dataPoints)
}

public enum CodableToolValue {
    case float(EditorToolKey, Float)
    case tint(EditorToolKey, TintValue)
    case blur(EditorToolKey, BlurValue)
    case curves(EditorToolKey, CurvesValue)
    
    public init?(key: EditorToolKey, value: Any) {
        if let toolValue = value as? Float {
            self = .float(key, toolValue)
        } else if let toolValue = value as? TintValue {
            self = .tint(key, toolValue)
        } else if let toolValue = value as? BlurValue {
            self = .blur(key, toolValue)
        } else if let toolValue = value as? CurvesValue {
            self = .curves(key, toolValue)
        } else {
            return nil
        }
    }
    
    public var keyAndValue: (EditorToolKey, Any) {
        switch self {
        case let .float(key, value):
            return (key, value)
        case let .tint(key, value):
            return (key, value)
        case let .blur(key, value):
            return (key, value)
        case let .curves(key, value):
            return (key, value)
        }
    }
}

extension CodableToolValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case key
        case type
        case value
    }

    private enum ToolType: Int, Codable {
        case float
        case tint
        case blur
        case curves
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ToolType.self, forKey: .type)
        let key = EditorToolKey(rawValue: try container.decode(Int32.self, forKey: .key))!
        switch type {
        case .float:
            self = .float(key, try container.decode(Float.self, forKey: .value))
        case .tint:
            self = .tint(key, try container.decode(TintValue.self, forKey: .value))
        case .blur:
            self = .blur(key, try container.decode(BlurValue.self, forKey: .value))
        case .curves:
            self = .curves(key, try container.decode(CurvesValue.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .float(key, value):
            try container.encode(key.rawValue, forKey: .key)
            try container.encode(ToolType.float, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .tint(key, value):
            try container.encode(key.rawValue, forKey: .key)
            try container.encode(ToolType.tint, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .blur(key, value):
            try container.encode(key.rawValue, forKey: .key)
            try container.encode(ToolType.blur, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .curves(key, value):
            try container.encode(key.rawValue, forKey: .key)
            try container.encode(ToolType.curves, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

private let hasHEVCHardwareEncoder: Bool = {
    let spec: [CFString: Any] = [:]
    var outID: CFString?
    var properties: CFDictionary?
    let result = VTCopySupportedPropertyDictionaryForEncoder(width: 1920, height: 1080, codecType: kCMVideoCodecType_HEVC, encoderSpecification: spec as CFDictionary, encoderIDOut: &outID, supportedPropertiesOut: &properties)
    if result == kVTCouldNotFindVideoEncoderErr {
        return false
    }
    return result == noErr
}()


func targetSize(cropSize: CGSize, rotateSideward: Bool = false) -> CGSize {
    let blockSize: CGFloat = 16.0
    
    var adjustedCropSize = cropSize
    if rotateSideward {
        adjustedCropSize = CGSize(width: cropSize.height, height: cropSize.width)
    }
    
    let renderWidth = (adjustedCropSize.width / blockSize).rounded(.down) * blockSize
    let renderHeight = (adjustedCropSize.height * renderWidth / adjustedCropSize.width).rounded(.down)
    
//    if fmod(renderHeight, blockSize) != 0 {
//        renderHeight = (adjustedCropSize.height / blockSize).rounded(.down) * blockSize
//    }
    
    return CGSize(width: renderWidth, height: renderHeight)
}

public func recommendedVideoExportConfiguration(values: MediaEditorValues, duration: Double, image: Bool = false, forceFullHd: Bool = false, frameRate: Float, isSticker: Bool = false) -> MediaEditorVideoExport.Configuration {
    let compressionProperties: [String: Any]
    let codecType: Any
    
    var values = values
    
    var videoBitrate: Int = 3700
    var audioBitrate: Int = 64
    var audioNumberOfChannels = 2
    if image {
        videoBitrate = 5000
    } else {
        if duration < 10 {
            videoBitrate = 5800
        } else if duration < 20 {
            videoBitrate = 5500
        } else if duration < 30 {
            videoBitrate = 5000
        }
    }

    let width: Int
    let height: Int
    
    var frameRate = frameRate
    
    var useHEVC = hasHEVCHardwareEncoder
    var useVP9 = false
    if let qualityPreset = values.qualityPreset {
        let maxSize = CGSize(width: qualityPreset.maximumDimensions, height: qualityPreset.maximumDimensions)
        var resultSize = values.originalDimensions.cgSize
        if let cropRect = values.cropRect, !cropRect.isEmpty {
            resultSize = targetSize(cropSize: cropRect.size.aspectFitted(maxSize), rotateSideward: values.cropOrientation?.isSideward ?? false)
        } else {
            resultSize = targetSize(cropSize: resultSize.aspectFitted(maxSize), rotateSideward: values.cropOrientation?.isSideward ?? false)
        }
        
        width = Int(resultSize.width)
        height = Int(resultSize.height)
        
        videoBitrate = qualityPreset.videoBitrateKbps
        audioBitrate = qualityPreset.audioBitrateKbps
        audioNumberOfChannels = qualityPreset.audioChannelsCount
        
        useHEVC = false
    } else {
        if isSticker {
            width = 512
            height = 512
            useVP9 = true
            frameRate = 30
            values = values.withUpdatedQualityPreset(.sticker)
        } else if values.videoIsFullHd {
            width = 1080
            height = 1920
        } else {
            width = 720
            height = 1280
        }
    }
    
    if useVP9 {
        codecType = "VP9"
        compressionProperties = [:]
    } else if useHEVC {
        codecType = AVVideoCodecType.hevc
        compressionProperties = [
            AVVideoAverageBitRateKey: videoBitrate * 1000,
            AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel
        ]
    } else {
        codecType = AVVideoCodecType.h264
        compressionProperties = [
            AVVideoAverageBitRateKey: videoBitrate * 1000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]
    }
    
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: codecType,
        AVVideoCompressionPropertiesKey: compressionProperties,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height
    ]
    
    let audioSettings: [String: Any]
    if isSticker {
        audioSettings = [:]
    } else {
        audioSettings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: audioBitrate * 1000,
            AVNumberOfChannelsKey: audioNumberOfChannels
        ]
    }
    
    return MediaEditorVideoExport.Configuration(
        videoSettings: videoSettings,
        audioSettings: audioSettings,
        values: values,
        frameRate: frameRate,
        preferredDuration: isSticker ? duration: nil
    )
}
