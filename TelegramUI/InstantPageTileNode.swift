import Foundation
import AsyncDisplayKit

private final class InstantPageTileNodeParameters: NSObject {
    let tile: InstantPageTile
    
    init(tile: InstantPageTile) {
        self.tile = tile
        
        super.init()
    }
}

final class InstantPageTileNode: ASDisplayNode {
    private let tile: InstantPageTile
    
    init(tile: InstantPageTile) {
        self.tile = tile
        
        super.init()
        
        self.isLayerBacked = true
        self.isOpaque = true
        self.backgroundColor = UIColor.white
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageTileNodeParameters(tile: self.tile)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: () -> Bool, isRasterizing: Bool) {
        
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? InstantPageTileNodeParameters {
            parameters.tile.draw(context: context)
        }
    }
}
