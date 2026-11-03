import Foundation
import simd

/// How shapes are described to the shaders: the `liquidGlassShapeKind` function constant (index 0) that every
/// render pipeline is specialized with.
public enum LiquidGlassShapeKind: Int32 {
    /// A height for each x; a shape fills everything above its crest (the call status bar's waves).
    case crest = 0
    /// A radius for each angle around a centre; a shape fills everything inside its outline (the recording blob).
    case radial = 1
}

/// How the three shapes are drawn.
public enum LiquidGlassRenderMode: Int32 {
    /// The color masked by the shapes at their plain alphas, drawn source-over.
    case plain = 0
    /// Liquid glass over a refracted backdrop (iOS 26 and later).
    case glass = 1
    /// The main shape only, solid, for energy saving.
    case flat = 2
}

/// The look of one of the three shapes. Shapes are drawn bottom to top: outer, middle, main.
public struct LiquidGlassLayerStyle: Equatable {
    /// Opacity of the shape in the glass style.
    public var alpha: Float
    /// Density of the color fill under the glass.
    public var fill: Float
    /// Strength of the color multiplied over the shape: keeps it saturated without hiding what is behind.
    public var saturation: Float
    /// White matte under the color: multiplied over dark content, the color alone would vanish.
    public var matte: Float
    /// Opacity of the highlight along the edge.
    public var rim: Float
    public var refracts: Bool
    /// Opacity of the shape in the plain style.
    public var plainAlpha: Float

    public init(alpha: Float, fill: Float, saturation: Float, matte: Float, rim: Float, refracts: Bool, plainAlpha: Float) {
        self.alpha = alpha
        self.fill = fill
        self.saturation = saturation
        self.matte = matte
        self.rim = rim
        self.refracts = refracts
        self.plainAlpha = plainAlpha
    }
}

public struct LiquidGlassAppearance: Equatable {
    /// Exactly three, bottom to top: outer, middle, main.
    public var layers: [LiquidGlassLayerStyle]
    /// A soft shadow under the outer shape.
    public var shadowStrength: Float
    public var shadowBlur: Float
    public var shadowDrop: Float
    public var rimWidth: Float
    /// Rims are dimmed by this factor in dark appearances.
    public var rimDarkAppearanceScale: Float
    /// Width of the refracting band along each edge.
    public var glassBand: Float
    /// How far content is pulled in at the very edge. Above half of `glassBand` the falloff folds content back on
    /// itself near the edge, mirroring it.
    public var glassShift: Float

    public init(layers: [LiquidGlassLayerStyle], shadowStrength: Float, shadowBlur: Float, shadowDrop: Float, rimWidth: Float, rimDarkAppearanceScale: Float, glassBand: Float, glassShift: Float) {
        precondition(layers.count == 3)
        self.layers = layers
        self.shadowStrength = shadowStrength
        self.shadowBlur = shadowBlur
        self.shadowDrop = shadowDrop
        self.rimWidth = rimWidth
        self.rimDarkAppearanceScale = rimDarkAppearanceScale
        self.glassBand = glassBand
        self.glassShift = glassShift
    }
}

public enum LiquidGlassShapesConstants {
    /// Must match `liquidGlassCrestPointCount` and `liquidGlassCrestSampleCount` in LiquidGlassShapes.metal.
    public static let crestPointCount = 6
    public static let crestSampleCount = 128
    /// Must match `liquidGlassRadialPointCount` and `liquidGlassRadialSampleCount` in LiquidGlassShapes.metal.
    public static let radialPointCount = 8
    public static let radialSampleCount = 256
    /// The displacement map encodes offsets up to this many points; covers the pulls of overlapping edges.
    public static let displacementAmount: Float = 32.0
}

public typealias LiquidGlassCrestPoints = (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)

/// Must match `LiquidGlassCrestShape` in LiquidGlassShapes.metal.
public struct LiquidGlassCrestShape {
    /// Normalized: x in 0...1 across the layer, y in units of the amplitude.
    public var fromPoints: LiquidGlassCrestPoints
    public var toPoints: LiquidGlassCrestPoints
    /// Eased progress from `fromPoints` to `toPoints`.
    public var progress: Float
    /// How far the shape has sunk, in points.
    public var offset: Float

    public init(fromPoints: LiquidGlassCrestPoints, toPoints: LiquidGlassCrestPoints, progress: Float, offset: Float) {
        self.fromPoints = fromPoints
        self.toPoints = toPoints
        self.progress = progress
        self.offset = offset
    }

    /// The resting line.
    public static var flat: LiquidGlassCrestShape {
        let segment = 1.0 / Float(LiquidGlassShapesConstants.crestPointCount - 1)
        let points: LiquidGlassCrestPoints = (SIMD2(0.0, 0.0), SIMD2(segment, 0.0), SIMD2(segment * 2.0, 0.0), SIMD2(segment * 3.0, 0.0), SIMD2(segment * 4.0, 0.0), SIMD2(1.0, 0.0))
        return LiquidGlassCrestShape(fromPoints: points, toPoints: points, progress: 0.0, offset: 0.0)
    }
}

/// Must match `LiquidGlassCrestParameters` in LiquidGlassShapes.metal.
public struct LiquidGlassCrestParameters {
    public var shapes: (LiquidGlassCrestShape, LiquidGlassCrestShape, LiquidGlassCrestShape)
    public var width: Float
    /// Where crests rest, in points from the top of the layer.
    public var restY: Float
    public var amplitude: Float
    public var smoothness: Float

    public init(shapes: (LiquidGlassCrestShape, LiquidGlassCrestShape, LiquidGlassCrestShape), width: Float, restY: Float, amplitude: Float, smoothness: Float) {
        self.shapes = shapes
        self.width = width
        self.restY = restY
        self.amplitude = amplitude
        self.smoothness = smoothness
    }
}

public typealias LiquidGlassRadialPoints = (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)

/// Must match `LiquidGlassRadialShape` in LiquidGlassShapes.metal.
public struct LiquidGlassRadialShape {
    /// Normalized, relative to the centre, in units of `LiquidGlassRadialParameters.size`: 0.5 reaches the edge.
    /// The points go round in order, every one at a different angle.
    public var fromPoints: LiquidGlassRadialPoints
    public var toPoints: LiquidGlassRadialPoints
    /// Eased progress from `fromPoints` to `toPoints`.
    public var progress: Float
    /// Scale of the outline around the centre.
    public var scale: Float

    public init(fromPoints: LiquidGlassRadialPoints, toPoints: LiquidGlassRadialPoints, progress: Float, scale: Float) {
        self.fromPoints = fromPoints
        self.toPoints = toPoints
        self.progress = progress
        self.scale = scale
    }

    /// A circle `scale` of the size across. The smooth curve through its eight points is the standard cubic circle.
    public static func circle(scale: Float) -> LiquidGlassRadialShape {
        func point(_ index: Int) -> SIMD2<Float> {
            let angle = 2.0 * Double.pi * Double(index) / Double(LiquidGlassShapesConstants.radialPointCount)
            return SIMD2<Float>(Float(sin(angle) * 0.5), Float(cos(angle) * 0.5))
        }
        let points: LiquidGlassRadialPoints = (point(0), point(1), point(2), point(3), point(4), point(5), point(6), point(7))
        return LiquidGlassRadialShape(fromPoints: points, toPoints: points, progress: 0.0, scale: scale)
    }
}

/// Must match `LiquidGlassRadialParameters` in LiquidGlassShapes.metal.
public struct LiquidGlassRadialParameters {
    public var shapes: (LiquidGlassRadialShape, LiquidGlassRadialShape, LiquidGlassRadialShape)
    /// The side of the square the normalized points refer to, in points.
    public var size: Float
    public var smoothness: Float

    public init(shapes: (LiquidGlassRadialShape, LiquidGlassRadialShape, LiquidGlassRadialShape), size: Float, smoothness: Float) {
        self.shapes = shapes
        self.size = size
        self.smoothness = smoothness
    }
}

/// One frame's shapes.
public enum LiquidGlassShapeSet {
    case crest(LiquidGlassCrestParameters)
    /// `center` is in the layer's coordinates, in points.
    case radial(LiquidGlassRadialParameters, center: SIMD2<Float>)
}

/// Must match `LiquidGlassShapesUniforms` in LiquidGlassShapes.metal field for field.
public struct LiquidGlassShapesUniforms {
    public var gradientColor0: SIMD4<Float>
    public var gradientColor1: SIMD4<Float>
    public var layerStyle: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    public var layerRimGlass: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    public var boundsSize: SIMD2<Float>
    /// Set per pass.
    public var renderSize: SIMD2<Float>
    public var edgeInset: Float
    public var gradientLength: Float
    public var crestSpacing: Float
    public var shadowStrength: Float
    public var shadowSigma: Float
    public var shadowDrop: Float
    public var rimScale: Float
    public var rimWidth: Float
    public var glassBand: Float
    public var glassShift: Float
    public var glassAmount: Float
    public var mode: Int32
    public var shapeCenter: SIMD2<Float>
    /// Pads the struct to its stride (and the shader's size): it is uploaded with its stride.
    private var alignmentPadding = SIMD2<Float>()

    public init(appearance: LiquidGlassAppearance, colors: (SIMD4<Float>, SIMD4<Float>), boundsSize: CGSize, gradientLength: CGFloat, shapeCenter: SIMD2<Float>, mode: LiquidGlassRenderMode, isDarkAppearance: Bool, edgeInset: Float) {
        func styleVector(_ style: LiquidGlassLayerStyle) -> SIMD4<Float> {
            return SIMD4<Float>(style.alpha, style.fill, style.saturation, style.matte)
        }
        func rimGlassVector(_ style: LiquidGlassLayerStyle) -> SIMD4<Float> {
            return SIMD4<Float>(style.rim, style.refracts ? 1.0 : 0.0, style.plainAlpha, 0.0)
        }
        let layers = appearance.layers
        self.gradientColor0 = colors.0
        self.gradientColor1 = colors.1
        self.layerStyle = (styleVector(layers[0]), styleVector(layers[1]), styleVector(layers[2]))
        self.layerRimGlass = (rimGlassVector(layers[0]), rimGlassVector(layers[1]), rimGlassVector(layers[2]))
        self.boundsSize = SIMD2<Float>(Float(boundsSize.width), Float(boundsSize.height))
        self.renderSize = SIMD2<Float>()
        self.edgeInset = edgeInset
        self.gradientLength = Float(gradientLength)
        self.crestSpacing = Float(boundsSize.width / CGFloat(LiquidGlassShapesConstants.crestSampleCount - 1))
        self.shadowStrength = appearance.shadowStrength
        self.shadowSigma = appearance.shadowBlur
        self.shadowDrop = appearance.shadowDrop
        self.rimScale = isDarkAppearance ? appearance.rimDarkAppearanceScale : 1.0
        self.rimWidth = appearance.rimWidth
        self.glassBand = appearance.glassBand
        self.glassShift = appearance.glassShift
        self.glassAmount = LiquidGlassShapesConstants.displacementAmount
        self.mode = mode.rawValue
        self.shapeCenter = shapeCenter
    }
}
