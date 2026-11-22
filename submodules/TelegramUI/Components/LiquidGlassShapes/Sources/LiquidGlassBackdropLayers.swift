import Foundation
import UIKit
import Display
import MetalEngine
import GlassBackgroundComponent

/// Backdrop of the content behind a layer, warped by a displacement map that MetalEngine renders into a sibling
/// sublayer: the trick SpaceWarpNode uses for its ripple. The backdrop is slightly blurred and masked to the shapes,
/// so that only the content under them is softened.
final class LiquidGlassBackdropLayers {
    let containerLayer: SimpleLayer
    let backdropLayer: CALayer
    let backdropMaskLayer: MetalEngineSubjectLayer
    let displacementMapLayer: MetalEngineSubjectLayer
    private let backdropLayerDelegate: SimpleLayerDelegate

    init?(blurRadius: CGFloat, scale: CGFloat) {
        guard let displacementMapFilter = CALayer.displacementMap(), let backdropLayer = createBackdropLayer() else {
            return nil
        }
        self.backdropLayer = backdropLayer
        self.backdropLayerDelegate = SimpleLayerDelegate()
        self.containerLayer = SimpleLayer()
        self.backdropMaskLayer = MetalEngineSubjectLayer()
        self.displacementMapLayer = MetalEngineSubjectLayer()

        self.containerLayer.masksToBounds = false
        self.containerLayer.rasterizationScale = UIScreenScale

        backdropLayer.delegate = self.backdropLayerDelegate
        backdropLayer.setValue(scale as NSNumber, forKey: "scale")
        backdropLayer.rasterizationScale = scale
        if let blurFilter = CALayer.blur() {
            blurFilter.setValue(blurRadius as NSNumber, forKey: "inputRadius")
            backdropLayer.filters = [blurFilter]
        }
        self.backdropMaskLayer.magnificationFilter = .linear
        backdropLayer.mask = self.backdropMaskLayer
        self.containerLayer.addSublayer(backdropLayer)

        let displacementMapLayerName = "liquidGlassDisplacementMap"
        self.displacementMapLayer.name = displacementMapLayerName
        self.displacementMapLayer.zPosition = -1.0
        self.displacementMapLayer.magnificationFilter = .linear
        self.containerLayer.addSublayer(self.displacementMapLayer)

        displacementMapFilter.setValue(displacementMapLayerName, forKey: "inputSourceSublayerName")
        displacementMapFilter.setValue((-LiquidGlassShapesConstants.displacementAmount) as NSNumber, forKey: "inputAmount")
        displacementMapFilter.setValue(NSValue(cgPoint: CGPoint(x: 0.5, y: 0.5)), forKey: "inputOffset")
        self.containerLayer.filters = [displacementMapFilter]
    }

    func updateFrame(_ frame: CGRect) {
        self.containerLayer.frame = frame
        let bounds = CGRect(origin: CGPoint(), size: frame.size)
        self.backdropLayer.frame = bounds
        self.backdropMaskLayer.frame = bounds
        self.displacementMapLayer.frame = bounds
    }
}
