import Foundation
import UIKit

final class InstantPageTile {
    let frame: CGRect
    var items: [InstantPageItem] = []
    
    init(frame: CGRect) {
        self.frame = frame
    }
    
    func draw(context: CGContext) {
        context.translateBy(x: -self.frame.minX, y: -self.frame.minY)
        for item in self.items {
            item.drawInTile(context: context)
        }
//        context.setFillColor(UIColor.red.cgColor)
//        context.fill(CGRect(x: 0.0, y: self.frame.maxY - 1.0, width: self.frame.width, height: 2.0))
        context.translateBy(x: self.frame.minX, y: self.frame.minY)
    }
}

func instantPageTilesFromLayout(_ layout: InstantPageLayout, boundingWidth: CGFloat) -> [InstantPageTile] {
    var tileByOrigin: [Int: InstantPageTile] = [:]
    let tileHeight: CGFloat = 256.0
    
    for item in layout.items {
        if !item.wantsNode {
            let topTileIndex = max(0, Int(floor(item.frame.minY - 10.0) / tileHeight))
            let bottomTileIndex = max(topTileIndex, Int(floor(item.frame.maxY + 10.0) / tileHeight))
            for i in topTileIndex ... bottomTileIndex {
                let tile: InstantPageTile
                if let current = tileByOrigin[i] {
                    tile = current
                } else {
                    tile = InstantPageTile(frame: CGRect(x: 0.0, y: CGFloat(i) * tileHeight, width: boundingWidth, height: tileHeight))
                    tileByOrigin[i] = tile
                }
                tile.items.append(item)
            }
        }
    }
    
    return tileByOrigin.values.sorted(by: { lhs, rhs in
        return lhs.frame.minY < rhs.frame.minY
    })
}
