import Foundation

public protocol GridSection {
    var height: CGFloat { get }
    var hashValue: Int { get }
    
    func isEqual(to: GridSection) -> Bool
    func node() -> ASDisplayNode
}

public protocol GridItem {
    var section: GridSection? { get }
    func node(layout: GridNodeLayout) -> GridItemNode
    func update(node: GridItemNode)
}
