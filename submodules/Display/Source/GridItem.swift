import Foundation
import UIKit
import AsyncDisplayKit

public protocol GridSection {
    var height: CGFloat { get }
    var hashValue: Int { get }
    
    func isEqual(to: GridSection) -> Bool
    func node() -> ASDisplayNode
}

public protocol GridItem {
    var section: GridSection? { get }
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode
    func update(node: GridItemNode)
    var aspectRatio: CGFloat { get }
    var fillsRowWithHeight: (CGFloat, Bool)? { get }
    var fillsRowWithDynamicHeight: ((CGFloat) -> CGFloat)? { get }
}

public extension GridItem {
    var aspectRatio: CGFloat {
        return 1.0
    }
    
    var fillsRowWithHeight: (CGFloat, Bool)? {
        return nil
    }
    
    var fillsRowWithDynamicHeight: ((CGFloat) -> CGFloat)? {
        return nil
    }
}
