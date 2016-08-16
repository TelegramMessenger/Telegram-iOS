import Foundation
import Display
import AsyncDisplayKit
import Photos

private let testBackground = generateStretchableFilledCircleImage(radius: 8.0, color: UIColor.lightGray)

final class ActionSheetRollImageItem: ListViewItem {
    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
    }
    
    func nodeConfiguredForWidth(async: (() -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNode, () -> Void) -> Void) {
        async {
            let node = ActionSheetRollImageItemNode()
            node.contentSize = CGSize(width: 84.0, height: 84.0)
            node.insets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
            node.updateAsset(asset: self.asset)
            completion(node, {
            })
        }
    }
    
    func updateNode(async: (() -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: (ListViewItemNodeLayout, () -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets), {
        })
    }
}

private final class ActionSheetRollImageItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    
    init() {
        self.imageNode = ASImageNode()
        
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 84.0, height: 84.0))
        self.imageNode.displaysAsynchronously = true
        self.imageNode.clipsToBounds = true
        self.imageNode.cornerRadius = 8.0
        //self.imageNode.contentMode = .scaleToFill
        //self.imageNode.contentsScale = UIScreenScale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.imageNode)
    }
    
    func updateAsset(asset: PHAsset) {
        let retinaSquare = CGSize(width: 84.0 * UIScreenScale, height: 84.0 * UIScreenScale)
        
        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact;
        
        let cropSideLength = min(asset.pixelWidth, asset.pixelHeight)
        let square = CGRect(x: 0.0, y: 0.0, width: CGFloat(cropSideLength), height: CGFloat(cropSideLength))
        let cropRect = square.applying(CGAffineTransform(scaleX: 1.0 / CGFloat(asset.pixelWidth), y: 1.0 / CGFloat(asset.pixelHeight)))
        
        cropToSquare.normalizedCropRect = cropRect
        
        PHImageManager.default().requestImage(for: asset, targetSize: retinaSquare, contentMode: .aspectFit, options: cropToSquare, resultHandler: { [weak self] image, result in
            if let strongSelf = self, let image = image, let cgImage = image.cgImage {
                let orientedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
                strongSelf.imageNode.image = orientedImage
            }
        })
    }
}
