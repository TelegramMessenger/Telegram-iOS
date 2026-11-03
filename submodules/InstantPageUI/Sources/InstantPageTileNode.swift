import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class InstantPageTileNodeParameters: NSObject {
    let tile: InstantPageTile
    let backgroundColor: UIColor
    
    init(tile: InstantPageTile, backgroundColor: UIColor) {
        self.tile = tile
        self.backgroundColor = backgroundColor
        
        super.init()
    }
}

public final class InstantPageTileNode: ASDisplayNode {
    private var tile: InstantPageTile
    private var tileBackgroundColor: UIColor
    
    public init(tile: InstantPageTile, backgroundColor: UIColor) {
        self.tile = tile
        self.tileBackgroundColor = backgroundColor
        
        super.init()
        
        self.isLayerBacked = true
        self.isOpaque = false
        self.backgroundColor = backgroundColor
    }
    
    public func update(tile: InstantPageTile, backgroundColor: UIColor) {
        self.tile = tile
        self.tileBackgroundColor = backgroundColor
        self.backgroundColor = backgroundColor
        self.setNeedsDisplay()
    }
    
    public override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageTileNodeParameters(tile: self.tile, backgroundColor: self.tileBackgroundColor)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? InstantPageTileNodeParameters {
            if !isRasterizing {
                if !parameters.backgroundColor.alpha.isZero {
                    context.setBlendMode(.copy)
                    context.setFillColor(parameters.backgroundColor.cgColor)
                    context.fill(bounds)
                }
            }
            
            parameters.tile.draw(context: context)
        }
    }
}
