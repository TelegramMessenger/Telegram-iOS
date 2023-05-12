import Foundation
import UIKit
import Display
import TelegramCore

public enum EditorToolKey {
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
}
private let adjustmentToolsKeys: [EditorToolKey] = [
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

public struct TintValue: Equatable {
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
    
    public func withUpdatedColor(_ color: UIColor) -> TintValue {
        return TintValue(color: color, intensity: self.intensity)
    }
    
    public func withUpdatedIntensity(_ intensity: Float) -> TintValue {
        return TintValue(color: self.color, intensity: intensity)
    }
}

public struct BlurValue: Equatable {
    public static let initial = BlurValue(
        mode: .off,
        intensity: 0.5,
        position: CGPoint(x: 0.5, y: 0.5),
        size: 0.24,
        falloff: 0.12,
        rotation: 0.0
    )
    
    public enum Mode: Equatable {
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

public struct CurvesValue: Equatable {
    public struct CurveValue: Equatable {
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
                granularity: 100
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

public class MediaEditorValues {
    public let originalDimensions: PixelDimensions
    public let cropOffset: CGPoint
    public let cropSize: CGSize?
    public let cropScale: CGFloat
    public let cropRotation: CGFloat
    public let cropMirroring: Bool
    
    public let gradientColors: [UIColor]?
    
    public let videoTrimRange: Range<Double>?
    public let videoIsMuted: Bool
    
    public let drawing: UIImage?
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
        drawing: UIImage?,
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
        self.drawing = drawing
        self.toolValues = toolValues
    }
    
    func withUpdatedCrop(offset: CGPoint, scale: CGFloat, rotation: CGFloat, mirroring: Bool) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: offset, cropSize: self.cropSize, cropScale: scale, cropRotation: rotation, cropMirroring: mirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, drawing: self.drawing, toolValues: self.toolValues)
    }
    
    func withUpdatedGradientColors(gradientColors: [UIColor]) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, drawing: self.drawing, toolValues: self.toolValues)
    }
    
    func withUpdatedVideoIsMuted(_ videoIsMuted: Bool) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: videoIsMuted, drawing: self.drawing, toolValues: self.toolValues)
    }
    
    func withUpdatedToolValues(_ toolValues: [EditorToolKey: Any]) -> MediaEditorValues {
        return MediaEditorValues(originalDimensions: self.originalDimensions, cropOffset: self.cropOffset, cropSize: self.cropSize, cropScale: self.cropScale, cropRotation: self.cropRotation, cropMirroring: self.cropMirroring, gradientColors: self.gradientColors, videoTrimRange: self.videoTrimRange, videoIsMuted: self.videoIsMuted, drawing: self.drawing, toolValues: toolValues)
    }
}

private let toolEpsilon: Float = 0.005
public extension MediaEditorValues {
    var hasAdjustments: Bool {
        for key in adjustmentToolsKeys {
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
        if let blurValue = self.toolValues[.blur] as? BlurValue, blurValue.mode != .off || blurValue.intensity > toolEpsilon {
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
        }
        
        self.luminance = HistogramBins(values: [], max: 0)
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

public func curveThroughPoints(count: Int, valueAtIndex: (Int) -> Float, positionAtIndex: (Int, CGFloat) -> CGFloat, size: CGSize, type: MediaEditorCurveType, granularity: Int) -> (UIBezierPath, [Float]) {
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
        return CGPoint(x: floorToScreenPixels(positionAtIndex(index, step)), y: floorToScreenPixels(CGFloat(valueAtIndex(index)) * size.height))
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
            
            if ((index - 1) % 2 == 0) {
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
