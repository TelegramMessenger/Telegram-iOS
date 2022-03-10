import Foundation
import QuartzCore

final class MyPreCompositionLayer: MyCompositionLayer {

    let frameRate: CGFloat
    let remappingNode: NodeProperty<Vector1D>?
    fileprivate var animationLayers: [MyCompositionLayer]

    init(precomp: PreCompLayerModel,
         asset: PrecompAsset,
         assetLibrary: AssetLibrary?,
         frameRate: CGFloat) {
        self.animationLayers = []
        if let keyframes = precomp.timeRemapping?.keyframes {
            self.remappingNode = NodeProperty(provider: KeyframeInterpolator(keyframes: keyframes))
        } else {
            self.remappingNode = nil
        }
        self.frameRate = frameRate
        super.init(layer: precomp, size: CGSize(width: precomp.width, height: precomp.height))
        bounds = CGRect(origin: .zero, size: CGSize(width: precomp.width, height: precomp.height))

        //NOTE
        //contentsLayer.masksToBounds = true
        //contentsLayer.bounds = bounds

        let layers = initializeCompositionLayers(layers: asset.layers, assetLibrary: assetLibrary, frameRate: frameRate)

        var imageLayers = [MyImageCompositionLayer]()

        var mattedLayer: MyCompositionLayer? = nil

        for layer in layers.reversed() {
            layer.bounds = bounds
            //NOTE
            animationLayers.append(layer)
            if let imageLayer = layer as? MyImageCompositionLayer {
                imageLayers.append(imageLayer)
            }
            if let matte = mattedLayer {
                /// The previous layer requires this layer to be its matte
                matte.matteLayer = layer
                mattedLayer = nil
                continue
            }
            if let matte = layer.matteType,
               (matte == .add || matte == .invert) {
                /// We have a layer that requires a matte.
                mattedLayer = layer
            }
            //NOTE
            //contentsLayer.addSublayer(layer)
        }

        //NOTE
        //layerImageProvider.addImageLayers(imageLayers)
    }

    override func displayContentsWithFrame(frame: CGFloat, forceUpdates: Bool) {
        let localFrame: CGFloat
        if let remappingNode = remappingNode {
            remappingNode.update(frame: frame)
            localFrame = remappingNode.value.cgFloatValue * frameRate
        } else {
            localFrame = (frame - startFrame) / timeStretch
        }
        for animationLayer in self.animationLayers {
            animationLayer.displayWithFrame(frame: localFrame, forceUpdates: forceUpdates)
        }
    }

    override func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        return nil
    }

    override func captureChildren() -> [CapturedGeometryNode] {
        var result: [CapturedGeometryNode] = []
        for animationLayer in self.animationLayers {
            result.append(animationLayer.captureGeometry())
        }
        return result
    }
}
