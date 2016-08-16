import Foundation
import UIKit
import Display

private let titleFont = Font.regular(17.0)

class ListControllerButtonItem: ListControllerGroupableItem {
    private let title: String
    private let action: () -> ()
    private let color: UIColor
    
    let selectable: Bool = true
    
    init(title: String, action: () -> (), color: UIColor = .blue) {
        self.title = title
        self.action = action
        self.color = color
    }
    
    func setupNode(async: (() -> Void) -> Void, completion: (ListControllerGroupableItemNode) -> Void) {
        let node = ListControllerButtonItemNode()
        completion(node)
    }
    
    func selected() {
        self.action()
    }
}

class ListControllerButtonItemNode: ListControllerGroupableItemNode {
    let label: TextNode
    
    override init() {
        self.label = TextNode()
        
        super.init()
        
        self.label.isLayerBacked = true
        self.addSubnode(self.label)
    }
    
    override func asyncLayoutContent() -> (item: ListControllerGroupableItem, width: CGFloat) -> (CGSize, () -> Void) {
        let layoutLabel = TextNode.asyncLayout(self.label)
        return { item, width in
            if let item = item as? ListControllerButtonItem {
                let (labelLayout, labelApply) = layoutLabel(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.color), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), cutout: nil)
                return (CGSize(width: width, height: 44.0), { [weak self] in
                    if let strongSelf = self {
                        let _ = labelApply()
                        
                        strongSelf.label.frame = CGRect(origin: CGPoint(x: 16.0, y: floorToScreenPixels((44.0 - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                    }
                })
            } else {
                return (CGSize(width: width, height: 0.0), {
                })
            }
        }
    }
}
