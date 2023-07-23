import Foundation
import simd

final class MediaEditorRenderChain {
    let enhancePass = EnhanceRenderPass()
    let sharpenPass = SharpenRenderPass()
    let blurPass = BlurRenderPass()
    let adjustmentsPass = AdjustmentsRenderPass()
    
    var renderPasses: [RenderPass] {
        return [
            self.enhancePass,
            self.sharpenPass,
            self.blurPass,
            self.adjustmentsPass
        ]
    }
    
    func update(values: MediaEditorValues) {
        for key in EditorToolKey.allCases {
            let value = values.toolValues[key]
            switch key {
            case .enhance:
                if let value = value as? Float {
                    self.enhancePass.value = abs(value)
                } else {
                    self.enhancePass.value = 0.0
                }
            case .brightness:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.exposure = value
                } else {
                    self.adjustmentsPass.adjustments.exposure = 0.0
                }
            case .contrast:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.contrast = value
                } else {
                    self.adjustmentsPass.adjustments.contrast = 0.0
                }
            case .saturation:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.saturation = value
                } else {
                    self.adjustmentsPass.adjustments.saturation = 0.0
                }
            case .warmth:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.warmth = value
                } else {
                    self.adjustmentsPass.adjustments.warmth = 0.0
                }
            case .fade:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.fade = value
                } else {
                    self.adjustmentsPass.adjustments.fade = 0.0
                }
            case .highlights:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.highlights = value
                } else {
                    self.adjustmentsPass.adjustments.highlights = 0.0
                }
            case .shadows:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.shadows = value
                } else {
                    self.adjustmentsPass.adjustments.shadows = 0.0
                }
            case .vignette:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.vignette = value
                } else {
                    self.adjustmentsPass.adjustments.vignette = 0.0
                }
            case .grain:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.grain = value
                } else {
                    self.adjustmentsPass.adjustments.grain = 0.0
                }
            case .sharpen:
                if let value = value as? Float {
                    self.sharpenPass.value = value
                } else {
                    self.sharpenPass.value = 0.0
                }
            case .shadowsTint:
                if let value = value as? TintValue {
                    if value.color != .clear {
                        let (red, green, blue, _) = value.color.components
                        self.adjustmentsPass.adjustments.shadowsTintColor = simd_float3(Float(red), Float(green), Float(blue))
                        self.adjustmentsPass.adjustments.shadowsTintIntensity = value.intensity
                    } else {
                        self.adjustmentsPass.adjustments.shadowsTintIntensity = 0.0
                    }
                }
            case .highlightsTint:
                if let value = value as? TintValue {
                    if value.color != .clear {
                        let (red, green, blue, _) = value.color.components
                        self.adjustmentsPass.adjustments.shadowsTintColor = simd_float3(Float(red), Float(green), Float(blue))
                        self.adjustmentsPass.adjustments.highlightsTintIntensity = value.intensity
                    } else {
                        self.adjustmentsPass.adjustments.highlightsTintIntensity = 0.0
                    }
                }
            case .blur:
                if let value = value as? BlurValue {
                    switch value.mode {
                    case .off:
                        self.blurPass.mode = .off
                    case .linear:
                        self.blurPass.mode = .linear
                    case .radial:
                        self.blurPass.mode = .radial
                    case .portrait:
                        self.blurPass.mode = .portrait
                    }
                    self.blurPass.intensity = value.intensity
                    self.blurPass.value.size = Float(value.size)
                    self.blurPass.value.position = simd_float2(Float(value.position.x), Float(value.position.y))
                    self.blurPass.value.falloff = Float(value.falloff)
                    self.blurPass.value.rotation = Float(value.rotation)
                }
            case .curves:
                if var value = value as? CurvesValue {
                    let allDataPoints = value.all.dataPoints
                    let redDataPoints = value.red.dataPoints
                    let greenDataPoints = value.green.dataPoints
                    let blueDataPoints = value.blue.dataPoints
                    
                    self.adjustmentsPass.adjustments.hasCurves = 1.0
                    self.adjustmentsPass.allCurve = allDataPoints
                    self.adjustmentsPass.redCurve = redDataPoints
                    self.adjustmentsPass.greenCurve = greenDataPoints
                    self.adjustmentsPass.blueCurve = blueDataPoints
                } else {
                    self.adjustmentsPass.adjustments.hasCurves = 0.0
                }
            }
        }
    }
}
