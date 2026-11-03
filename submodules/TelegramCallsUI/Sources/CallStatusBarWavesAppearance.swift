import Foundation
import LiquidGlassShapes

/// The call status bar's look (the WaveLab prototype's defaults).
enum CallStatusBarWavesAppearance {
    /// Bottom to top.
    static let appearance = LiquidGlassAppearance(
        layers: [
            LiquidGlassLayerStyle(alpha: 0.35, fill: 0.5, saturation: 0.0, matte: 0.0, rim: 0.3, refracts: true, plainAlpha: 0.35),
            LiquidGlassLayerStyle(alpha: 0.55, fill: 0.5, saturation: 0.0, matte: 0.0, rim: 0.3, refracts: true, plainAlpha: 0.55),
            LiquidGlassLayerStyle(alpha: 1.0, fill: 0.0, saturation: 1.0, matte: 0.3, rim: 0.3, refracts: true, plainAlpha: 1.0)
        ],
        shadowStrength: 0.07,
        shadowBlur: 6.0,
        shadowDrop: 2.0,
        rimWidth: 1.0,
        rimDarkAppearanceScale: 0.45,
        glassBand: 20.0,
        glassShift: 10.0
    )
}
