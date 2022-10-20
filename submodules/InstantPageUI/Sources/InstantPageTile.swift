import Foundation
import UIKit
import Display

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
        context.translateBy(x: self.frame.minX, y: self.frame.minY)
    }
}

func instantPageTilesFromLayout(_ layout: InstantPageLayout, boundingWidth: CGFloat) -> [InstantPageTile] {
    var tileByOrigin: [Int : InstantPageTile] = [:]
    let tileHeight: CGFloat = 256.0
    
    var tileHoles: [CGRect] = []
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
        } else if item.separatesTiles {
            tileHoles.append(item.frame)
        }
    }
    
    var finalTiles: [InstantPageTile] = []
    var usedTiles = Set<Int>()
    
    for hole in tileHoles {
        let topTileIndex = max(0, Int(floor(hole.minY - 10.0) / tileHeight))
        let bottomTileIndex = max(topTileIndex, Int(floor(hole.maxY + 10.0) / tileHeight))
        for i in topTileIndex ... bottomTileIndex {
            if let tile = tileByOrigin[i] {
                if tile.frame.minY > hole.minY && tile.frame.minY < hole.maxY {
                    let delta = hole.maxY - tile.frame.minY
                    let updatedTile = InstantPageTile(frame: CGRect(origin: tile.frame.origin.offsetBy(dx: 0.0, dy: delta), size: CGSize(width: tile.frame.width, height: tile.frame.height - delta)))
                    updatedTile.items.append(contentsOf: tile.items)
                    finalTiles.append(updatedTile)
                    usedTiles.insert(i)
                } else if tile.frame.maxY > hole.minY && tile.frame.minY < hole.minY {
                    let delta = tile.frame.maxY - hole.minY
                    let updatedTile = InstantPageTile(frame: CGRect(origin: tile.frame.origin, size: CGSize(width: tile.frame.width, height: tile.frame.height - delta)))
                    updatedTile.items.append(contentsOf: tile.items)
                    finalTiles.append(updatedTile)
                    usedTiles.insert(i)
                }
            }
        }
        //let holeTile = InstantPageTile(frame: hole)
        //finalTiles.append(holeTile)
    }
    
    for (index, tile) in tileByOrigin {
        if !usedTiles.contains(index) {
            finalTiles.append(tile)
        }
    }

    return finalTiles.sorted(by: { lhs, rhs in
        return lhs.frame.minY < rhs.frame.minY
    })
}

func instantPageAccessibilityAreasFromLayout(_ layout: InstantPageLayout, boundingWidth: CGFloat) -> [AccessibilityAreaNode] {
    var result: [AccessibilityAreaNode] = []
    for item in layout.items {
        if let item = item as? InstantPageTextItem {
            let itemNode = AccessibilityAreaNode()
            itemNode.frame = item.frame
            itemNode.accessibilityTraits = .staticText
            itemNode.accessibilityLabel = item.attributedString.string
            result.append(itemNode)
        }
    }
    return result
}
