import Foundation
import UIKit

func initializeCompositionLayers(
    layers: [LayerModel],
    assetLibrary: AssetLibrary?,
    frameRate: CGFloat
) -> [MyCompositionLayer] {
    var compositionLayers = [MyCompositionLayer]()
    var layerMap = [Int : MyCompositionLayer]()

    /// Organize the assets into a dictionary of [ID : ImageAsset]
    var childLayers = [LayerModel]()

    for layer in layers {
        if layer.hidden == true {
            let genericLayer = MyNullCompositionLayer(layer: layer)
            compositionLayers.append(genericLayer)
            layerMap[layer.index] = genericLayer
        } else if let shapeLayer = layer as? ShapeLayerModel {
            let shapeContainer = MyShapeCompositionLayer(shapeLayer: shapeLayer)
            compositionLayers.append(shapeContainer)
            layerMap[layer.index] = shapeContainer
        } else if let solidLayer = layer as? SolidLayerModel {
            let solidContainer = MySolidCompositionLayer(solid: solidLayer)
            compositionLayers.append(solidContainer)
            layerMap[layer.index] = solidContainer
        } else if let precompLayer = layer as? PreCompLayerModel,
                  let assetLibrary = assetLibrary,
                  let precompAsset = assetLibrary.precompAssets[precompLayer.referenceID] {
            let precompContainer = MyPreCompositionLayer(precomp: precompLayer,
                                                       asset: precompAsset,
                                                       assetLibrary: assetLibrary,
                                                       frameRate: frameRate)
            compositionLayers.append(precompContainer)
            layerMap[layer.index] = precompContainer
        } else if let imageLayer = layer as? ImageLayerModel,
                  let assetLibrary = assetLibrary,
                  let imageAsset = assetLibrary.imageAssets[imageLayer.referenceID] {
            let imageContainer = MyImageCompositionLayer(imageLayer: imageLayer, size: CGSize(width: imageAsset.width, height: imageAsset.height))
            compositionLayers.append(imageContainer)
            layerMap[layer.index] = imageContainer
        } else if let _ = layer as? TextLayerModel {
            let genericLayer = MyNullCompositionLayer(layer: layer)
            compositionLayers.append(genericLayer)
            layerMap[layer.index] = genericLayer
            /*let textContainer = TextCompositionLayer(textLayer: textLayer, textProvider: textProvider, fontProvider: fontProvider)
            compositionLayers.append(textContainer)
            layerMap[layer.index] = textContainer*/
        } else {
            let genericLayer = MyNullCompositionLayer(layer: layer)
            compositionLayers.append(genericLayer)
            layerMap[layer.index] = genericLayer
        }
        if layer.parent != nil {
            childLayers.append(layer)
        }
    }

    /// Now link children with their parents
    for layerModel in childLayers {
        if let parentID = layerModel.parent {
            let childLayer = layerMap[layerModel.index]
            let parentLayer = layerMap[parentID]
            childLayer?.transformNode.parentNode = parentLayer?.transformNode
        }
    }

    return compositionLayers
}

final class MyAnimationContainer {
    let bounds: CGRect

    var currentFrame: CGFloat = 0.0

    /// Forces the view to update its drawing.
    func forceDisplayUpdate() {
        animationLayers.forEach( { $0.displayWithFrame(frame: currentFrame, forceUpdates: true) })
    }

    var animationLayers: [MyCompositionLayer]

    init(animation: Animation) {
        self.animationLayers = []

        self.bounds = CGRect(origin: CGPoint(), size: CGSize(width: animation.width, height: animation.height))
        let layers = initializeCompositionLayers(layers: animation.layers, assetLibrary: animation.assetLibrary, frameRate: CGFloat(animation.framerate))

        var imageLayers = [MyImageCompositionLayer]()

        var mattedLayer: MyCompositionLayer? = nil

        for layer in layers.reversed() {
            layer.bounds = bounds
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
            //addSublayer(layer)
        }
    }

    func setFrame(frame: CGFloat) {
        self.currentFrame = frame
        for animationLayer in self.animationLayers {
            animationLayer.displayWithFrame(frame: frame, forceUpdates: false)
        }
    }

    func captureGeometry() -> CapturedGeometryNode {
        var subnodes: [CapturedGeometryNode] = []
        for animationLayer in self.animationLayers {
            let capturedSubnode = animationLayer.captureGeometry()
            subnodes.append(capturedSubnode)
        }
        return CapturedGeometryNode(
            transform: CATransform3DIdentity,
            alpha: 1.0,
            isHidden: false,
            displayItem: nil,
            subnodes: subnodes
        )
    }
}
