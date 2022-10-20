import Foundation
import UIKit
import AsyncDisplayKit

private final class InstantPageTileNodeParameters: NSObject {
    let tile: InstantPageTile
    let backgroundColor: UIColor
    
    init(tile: InstantPageTile, backgroundColor: UIColor) {
        self.tile = tile
        self.backgroundColor = backgroundColor
        
        super.init()
    }
}

final class InstantPageTileNode: ASDisplayNode {
    private let tile: InstantPageTile
    
    init(tile: InstantPageTile, backgroundColor: UIColor) {
        self.tile = tile
        
        super.init()
        
        self.isLayerBacked = true
        self.isOpaque = false
        self.backgroundColor = backgroundColor
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageTileNodeParameters(tile: self.tile, backgroundColor: self.backgroundColor ?? UIColor.white)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? InstantPageTileNodeParameters {
            if !isRasterizing {
                context.setBlendMode(.copy)
                context.setFillColor(parameters.backgroundColor.cgColor)
                context.fill(bounds)
            }
            
            parameters.tile.draw(context: context)
        }
    }
}
