import Foundation

public protocol GridItem {
    func node(layout: GridNodeLayout) -> GridItemNode
}
