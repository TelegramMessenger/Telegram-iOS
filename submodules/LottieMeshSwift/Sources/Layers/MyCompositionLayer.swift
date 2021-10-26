import Foundation
import QuartzCore

/**
 The base class for a child layer of CompositionContainer
 */
class MyCompositionLayer {
    var bounds: CGRect = CGRect()

    let transformNode: LayerTransformNode

    //let contentsLayer: CALayer = CALayer()

    let maskLayer: MyMaskContainerLayer?

    let matteType: MatteType?

    var matteLayer: MyCompositionLayer? {
        didSet {
            //NOTE
            /*if let matte = matteLayer {
                if let type = matteType, type == .invert {

                    mask = InvertedMatteLayer(inputMatte: matte)
                } else {
                    mask = matte
                }
            } else {
                mask = nil
            }*/
        }
    }

    let inFrame: CGFloat
    let outFrame: CGFloat
    let startFrame: CGFloat
    let timeStretch: CGFloat

    init(layer: LayerModel, size: CGSize) {
        self.transformNode = LayerTransformNode(transform: layer.transform)
        if let masks = layer.masks {
            maskLayer = MyMaskContainerLayer(masks: masks)
        } else {
            maskLayer = nil
        }
        self.matteType = layer.matte
        self.inFrame = layer.inFrame.cgFloat
        self.outFrame = layer.outFrame.cgFloat
        self.timeStretch = layer.timeStretch.cgFloat
        self.startFrame = layer.startTime.cgFloat

        //NOTE
        //self.anchorPoint = .zero

        //NOTE
        /*contentsLayer.anchorPoint = .zero
        contentsLayer.bounds = CGRect(origin: .zero, size: size)
        contentsLayer.actions = [
            "opacity" : NSNull(),
            "transform" : NSNull(),
            "bounds" : NSNull(),
            "anchorPoint" : NSNull(),
            "sublayerTransform" : NSNull(),
            "hidden" : NSNull()
        ]
        addSublayer(contentsLayer)

        if let maskLayer = maskLayer {
            contentsLayer.mask = maskLayer
        }*/
    }

    private(set) var isHidden = false

    final func displayWithFrame(frame: CGFloat, forceUpdates: Bool) {
        transformNode.updateTree(frame, forceUpdates: forceUpdates)
        let layerVisible = frame.isInRangeOrEqual(inFrame, outFrame)
        /// Only update contents if current time is within the layers time bounds.
        if layerVisible {
            displayContentsWithFrame(frame: frame, forceUpdates: forceUpdates)
            maskLayer?.updateWithFrame(frame: frame, forceUpdates: forceUpdates)
        }
        self.isHidden = !layerVisible
        //NOTE
        /*contentsLayer.transform = transformNode.globalTransform
        contentsLayer.opacity = transformNode.opacity
        contentsLayer.isHidden = !layerVisible*/
    }

    func displayContentsWithFrame(frame: CGFloat, forceUpdates: Bool) {
        /// To be overridden by subclass
    }

    func captureGeometry() -> CapturedGeometryNode {
        return CapturedGeometryNode(
            transform: self.transformNode.globalTransform,
            alpha: CGFloat(self.transformNode.opacity),
            isHidden: self.isHidden,
            displayItem: self.captureDisplayItem(),
            subnodes: self.captureChildren()
        )
    }

    func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        preconditionFailure()
    }

    func captureChildren() -> [CapturedGeometryNode] {
        preconditionFailure()
    }
}
