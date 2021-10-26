import Foundation
import CoreGraphics
import QuartzCore

final class MyImageCompositionLayer: MyCompositionLayer {

    var image: CGImage? = nil {
        didSet {
            //NOTE
            /*if let image = image {
                contentsLayer.contents = image
            } else {
                contentsLayer.contents = nil
            }*/
        }
    }

    let imageReferenceID: String

    init(imageLayer: ImageLayerModel, size: CGSize) {
        self.imageReferenceID = imageLayer.referenceID
        super.init(layer: imageLayer, size: size)

        //NOTE
        //contentsLayer.masksToBounds = true
        //contentsLayer.contentsGravity = CALayerContentsGravity.resize
    }

    override func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        preconditionFailure()
    }

    override func captureChildren() -> [CapturedGeometryNode] {
        return []
    }
}
