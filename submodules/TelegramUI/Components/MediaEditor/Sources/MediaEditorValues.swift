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
    
    public init(additional: Bool, timestamp: Double) {
        self.additional = additional
        self.timestamp = timestamp
    }
}

public final class MediaEditorValues: Codable, Equatable {
    public static func == (lhs: MediaEditorValues, rhs: MediaEditorValues) -> Bool {
        if lhs.originalDimensions != rhs.originalDimensions {
            return false
        }
        if lhs.cropOffset != rhs.cropOffset {
            return false
        }
        if lhs.cropSize != rhs.cropSize {
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
        if lhs.additionalVideoPath != rhs.additionalVideoPath {
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
        if lhs.drawing !== rhs.drawing {
            return false
        }
        if lhs.entities != rhs.entities {
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
        case originalWidth
        case originalHeight
        case cropOffset
        case cropSize
        case cropScale
        case cropRotation
        case cropMirroring
        
        case gradientColors
        
        case videoTrimRange
        case videoIsMuted
        case videoIsFullHd
        case videoIsMirrored
        
        case additionalVideoPath
        case additionalVideoPosition
        case additionalVideoScale
        case additionalVideoRotation
        case additionalVideoPositionChanges
        
        case drawing
        case entities
        case toolValues
    }
    
    public let originalDimensions: PixelDimensions
    public let cropOffset: CGPoint
    public let cropSize: CGSize?
    public let cropScale: CGFloat
    public let cropRotation: CGFloat
    public let cropMirroring: Bool
    
    public let gradientColors: [UIColor]?
    
    public let videoTrimRange: Range<Double>?
    public let videoIsMuted: Bool
    public let videoIsFullHd: Bool
    public let videoIsMirrored: Bool
    
    public let additionalVideoPath: String?
    public let additionalVideoPosition: CGPoint?
    public let additionalVideoScale: CGFloat?
    public let additionalVideoRotation: CGFloat?
    public let additionalVideoPositionChanges: [VideoPositionChange]
    
    public let drawing: UIImage?
    public let entities: [CodableDrawingEntity]
    public let toolValues: [EditorToolKey: Any]
    
    init(
        originalDimensions: PixelDimensions,
        cropOffset: CGPoint,
        cropSize: CGSize?,
        cropScale: CGFloat,
        cropRotation: CGFloat,
        cropMirroring: Bool,
        gradientColors: [UIColor]?,
        videoTrimRange: Range<Double>?,
        videoIsMuted: Bool,
        videoIsFullHd: Bool,
        videoIsMirrored: Bool,
        additionalVideoPath: String?,
        additionalVideoPosition: CGPoint?,
        additionalVideoScale: CGFloat?,
        additionalVideoRotation: CGFloat?,
        additionalVideoPositionChanges: [VideoPositionChange],
        drawing: UIImage?,
        entities: [CodableDrawingEntity],
        toolValues: [EditorToolKey: Any]
    ) {
        self.originalDimensions = originalDimensions
        self.cropOffset = cropOffset
        self.cropSize = cropSize
        self.cropScale = cropScale
        self.cropRotation = cropRotation
        self.cropMirroring = cropMirroring
        self.gradientColors = gradientColors
        self.videoTrimRange = videoTrimRange
        self.videoIsMuted = videoIsMuted
        self.videoIsFullHd = videoIsFullHd
        self.videoIsMirrored = videoIsMirrored
        self.additionalVideoPath = additionalVideoPath
        self.additionalVideoPosition = additionalVideoPosition
        self.additionalVideoScale = additionalVideoScale
        self.additionalVideoRotation = additionalVideoRotation
        self.additionalVideoPositionChanges = additionalVideoPositionChanges
        self.drawing = drawing
        self.entities = entities
        self.toolValues = toolValues
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let width = try container.decode(Int32.self, forKey: .originalWidth)
        let height = try container.decode(Int32.self, forKey: .originalHeight)
        self.originalDimensions = PixelDimensions(width: width, height: height)
        
        self.cropOffset = try container.decode(CGPoint.self, forKey: .cropOffset)
        self.cropSize = try container.decodeIfPresent(CGSize.self, forKey: .cropSize)
        self.cropScale = try container.decode(CGFloat.self, forKey: .cropScale)
        self.cropRotation = try container.decode(CGFloat.self, forKey: .cropRotation)
        self.cropMirroring = try container.decode(Bool.self, forKey: .cropMirroring)
        
        if let gradientColors = try container.decodeIfPresent([DrawingColor].self, forKey: .gradientColors) {
            self.gradientColors = gradientColors.map { $0.toUIColor() }
        } else {
            self.gradientColors = nil
        }
        
        self.videoTrimRange = try container.decodeIfPresent(Range<Double>.self, forKey: .videoTrimRange)
        self.videoIsMuted = try container.decode(Bool.self, forKey: .videoIsMuted)
        self.videoIsFullHd = try container.decodeIfPresent(Bool.self, forKey: .videoIsFullHd) ?? false
        self.videoIsMirrored = try container.decodeIfPresent(Bool.self, forKey: .videoIsMirrored) ?? false
        
        self.additionalVideoPath = try container.decodeIfPresent(String.self, forKey: .additionalVideoPath)
        self.additionalVideoPosition = try container.decodeIfPresent(CGPoint.self, forKey: .additionalVideoPosition)
        self.additionalVideoScale = try container.decodeIfPresent(CGFloat.self, forKey: .additionalVideoScale)
        self.additionalVideoRotation = try container.decodeIfPresent(CGFloat.self, forKey: .additionalVideoRotation)
        self.additionalVideoPositionChanges = try container.decodeIfPresent([VideoPositionChange].self, forKey: .additionalVideoPositionChanges) ?? []
        
        if let drawingData = try container.decodeIfPresent(Data.self, forKey: .drawing), let image = UIImage(data: drawingData) {
            self.drawing = image
        } else {
            self.drawing = nil
        }
        
        self.entities = try container.decode([CodableDrawingEntity].self, forKey: .entities)
        
        let values = try container.decode([CodableToolValue].self, forKey: .toolValues)
        var toolValues: [EditorToolKey: Any] = [:]
        for value in values {
            let (key, value) = value.keyAndValue
            toolValues[key] = value
        }
        self.toolValues = toolValues
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.originalDimensions.width, forKey: .originalWidth)
        try container.encode(self.originalDimensions.height, forKey: .originalHeight)
        
        try container.encode(self.cropOffset, forKey: .cropOffset)
        try container.encode(self.cropSize, forKey: .cropSize)
        try container.encode(self.cropScale, forKey: .cropScale)
        try container.encode(self.cropRotation, forKey: .cropRotation)
        try container.encode(self.cropMirroring, forKey: .cropMirroring)
        
        if let gradientColors = self.gradientColors {
            try container.encode(gradientColors.map { DrawingColor(color: $0) }, forKey: .gradientColors)
        }
        
        try container.encodeIfPresent(self.videoTrimRange, forKey: .videoTrimRange)
        try container.encode(self.videoIsMuted, forKey: .videoIsMuted)
        try container.encode(self.videoIsFullHd, forKey: .videoIsFullHd)
        try container.encode(self.videoIsMirrored, forKey: .videoIsMirrored)
        
        try container.encodeIfPresent(self.additionalVideoPath, forKey: .additionalVideoPath)
        try container.encodeIfPresent(self.additionalVideoPosition, forKey: .additionalVideoPosition)
        try container.encodeIfPresent(self.additionalVideoScale, forKey: .additionalVideoScale)
        try container.encodeIfPresent(self.additionalVideoRotation, forKey: .additionalVideoRotation)
        try container.encodeIfPresent(self.additionalVideoPositionChanges, forKey: .additionalVideoPositionChanges)
        
        if let drawing = self.drawing, let pngDrawingData = drawing.pngData() {
            try container.encode(pngDrawingData, forKey: .drawing)
        }
        
        try container.encode(self.entities, forKey: .entities)
        
        var values: [CodableToolValue] = []
        for (key, value) in self.toolValues {
            if let toolValue = CodableToolValue(key: key, value: value) {
                values.append(toolValue)
            }
        }
        try container.encode(values, forKey: .toolValues)
    }
    
    public func makeCopy() -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedCrop(offset: CGPoint, scale: CGFloat, rotation: CGFloat, mirroring: Bool) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: offset, cropSize: self.cropSize, cropScale: scale, cropRotation: rotation, cropMirroring: mirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedGradientColors(gradientColors: [UIColor]) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedVideoIsMuted(_ videoIsMuted: Bool) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedVideoIsFullHd(_ videoIsFullHd: Bool) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    
    func withUpdatedVideoIsMirrored(_ videoIsMirrored: Bool) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedAdditionalVideo(path: String, positionChanges: [VideoPositionChange]) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: path, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: positionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedAdditionalVideo(position: CGPoint, scale: CGFloat, rotation: CGFloat) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: position, additionalVideoScale: scale, additionalVideoRotation: rotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedVideoTrimRange(_ videoTrimRange: Range<Double>) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: self.toolValues)
    }
    
    func withUpdatedDrawingAndEntities(drawing: UIImage?, entities: [CodableDrawingEntity]) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: drawing, entities: entities, toolValues: self.toolValues)
    }
    
    func withUpdatedToolValues(_ toolValues: [EditorToolKey: Any]) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, videoIsFullHd: self.videoIsFullHd, videoIsMirrored: self.videoIsMirrored, additionalVideoPath: self.additionalVideoPath, additionalVideoPosition: self.additionalVideoPosition, additionalVideoScale: self.additionalVideoScale, additionalVideoRotation: self.additionalVideoRotation, additionalVideoPositionChanges: self.additionalVideoPositionChanges, drawing: self.drawing, entities: self.entities, toolValues: toolValues)
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
        if self.originalDimensions.width > 0 && abs((Double(self.originalDimensions.height) / Double(self.originalDimensions.width)) - 1.7777778) > 0.001 {
            return true
        }
        if abs(1.0 - self.cropScale) > 0.0 {
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

public func recommendedVideoExportConfiguration(values: MediaEditorValues, duration: Double, image: Bool = false, forceFullHd: Bool = false, frameRate: Float) -> MediaEditorVideoExport.Configuration {
    let compressionProperties: [String: Any]
    let codecType: AVVideoCodecType
    
    var bitrate: Int = 3700
    if image {
        bitrate = 5000
    } else {
        if duration < 10 {
            bitrate = 5800
        } else if duration < 20 {
            bitrate = 5500
        } else if duration < 30 {
            bitrate = 5000
        }
    }
    if hasHEVCHardwareEncoder {
        codecType = AVVideoCodecType.hevc
        compressionProperties = [
            AVVideoAverageBitRateKey: bitrate * 1000,
            AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel
        ]
    } else {
        codecType = AVVideoCodecType.h264
        compressionProperties = [
            AVVideoAverageBitRateKey: bitrate * 1000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]
    }

    let width: Int
    let height: Int
    if values.videoIsFullHd {
        width = 1080
        height = 1920
    } else {
        width = 720
        height = 1280
    }
    
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: codecType,
        AVVideoCompressionPropertiesKey: compressionProperties,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height
    ]
    
    let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 64000,
        AVNumberOfChannelsKey: 2
    ]
    
    return MediaEditorVideoExport.Configuration(
        videoSettings: videoSettings,
        audioSettings: audioSettings,
        values: values,
        frameRate: frameRate
    )
}
