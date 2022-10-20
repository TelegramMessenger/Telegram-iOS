import Foundation
import UIKit
import Display
import AsyncDisplayKit

final class GridHoleItem: GridItem {
    let section: GridSection? = nil
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        return GridHoleItemNode()
    }
    
    func update(node: GridItemNode) {
    }
}

class GridHoleItemNode: GridItemNode {
    private let activityIndicatorView: UIActivityIndicatorView
    
    override init() {
        self.activityIndicatorView = UIActivityIndicatorView(style: .gray)
        
        super.init()
        
        self.view.addSubview(self.activityIndicatorView)
        self.activityIndicatorView.startAnimating()
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let activityIndicatorSize = self.activityIndicatorView.bounds.size
        self.activityIndicatorView.frame = CGRect(origin: CGPoint(x: floor((size.width - activityIndicatorSize.width) / 2.0), y: floor((size.height - activityIndicatorSize.height) / 2.0)), size: activityIndicatorSize)
    }
}
